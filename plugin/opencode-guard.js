import { closeSync, lstatSync, openSync, readFileSync, realpathSync, unlinkSync } from "node:fs"
import { basename, dirname, join, resolve } from "node:path"
import { homedir, tmpdir } from "node:os"

const HOME = realpathSync(homedir())
const ENGINE = join(HOME, "Library/Application Support/OpenCodeGuard")
const LIST = "~/OpenCode Guard/Guard List.txt"
const PROTECTED = [ENGINE, join(HOME, "OpenCode Guard"), join(HOME, ".config/opencode"), join(HOME, ".cc-safety-net")]
const SAFE_UNGUARDED = new Set([
  "read", "glob", "grep", "list", "webfetch", "websearch", "codesearch", "todoread", "todowrite",
  "question", "skill", "task", "lsp", "invalid", "plan_enter", "plan_exit",
])
const READS = new Set(["read", "glob", "grep", "list"])

const under = (p, root) => p === root || p.startsWith(root === "/" ? "/" : root + "/")

function canonical(p) {
  try {
    return realpathSync(p)
  } catch (error) {
    if (error.code !== "ENOENT") throw error
    let dangling = true
    try { lstatSync(p) } catch { dangling = false }
    if (dangling) throw new Error(`OpenCode Guard: dangling symlink ${p}`)
    const parent = dirname(p)
    if (parent === p) throw error
    return join(canonical(parent), basename(p))
  }
}

function guarded() {
  const probe = join(ENGINE, "state", `.probe-${process.pid}`)
  try {
    closeSync(openSync(probe, "w"))
    unlinkSync(probe)
    return false
  } catch (error) {
    return error.code === "EPERM"
  }
}

function loadRules() {
  try {
    return JSON.parse(readFileSync(join(ENGINE, "state/rules.json"), "utf8"))
  } catch {
    return null
  }
}

function patchPaths(text) {
  if (typeof text !== "string") return []
  return [...text.matchAll(/^\*\*\* (?:Add File|Update File|Delete File|Move to):(.*)$/gm)].map(m => m[1].trim())
}

export const OpenCodeGuard = async ({ directory }) => {
  const sandboxed = guarded()
  const bypass = process.env.OPENCODE_GUARD_BYPASS === "1"
  const rules = loadRules()
  const temps = [...new Set([canonical(tmpdir()), "/private/tmp"])]

  const target = raw => {
    if (typeof raw !== "string" || !raw || raw.includes("\0")) throw new Error("OpenCode Guard: invalid path")
    return canonical(resolve(directory, raw.replace(/^~(?=\/|$)/, HOME)))
  }

  const scope = p => {
    if (rules.deny.some(r => under(p, r))) return "deny"
    let best = "", kind = "none"
    for (const k of ["allow", "readonly"])
      for (const r of rules[k]) if (under(p, r) && r.length >= best.length) [best, kind] = [r, k]
    return kind
  }

  const checkRead = raw => {
    if (!rules) return
    const p = target(raw)
    if (scope(p) === "deny") throw new Error(`OpenCode Guard: ${p} is in the DENY list (${LIST}).`)
  }

  const checkWrite = raw => {
    const p = target(raw)
    if (PROTECTED.some(r => under(p, r))) throw new Error(`OpenCode Guard: ${p} is protected.`)
    if (!rules) throw new Error("OpenCode Guard: rules unavailable; relaunch OpenCode.")
    const kind = scope(p)
    if (kind === "deny") throw new Error(`OpenCode Guard: ${p} is in the DENY list (${LIST}).`)
    if (kind === "allow" || (kind === "none" && temps.some(r => under(p, r)))) return
    throw new Error(`OpenCode Guard: ${p} is not writable. Add it under ALLOW in ${LIST}, then relaunch.`)
  }

  return {
    "tool.execute.before": async ({ tool }, { args = {} }) => {
      if (!sandboxed && bypass) return
      if (!sandboxed && !SAFE_UNGUARDED.has(tool))
        throw new Error("OpenCode Guard: OpenCode was started without the guard. Quit it and open OpenCode Guarded, or run opencode from a new terminal.")
      if (READS.has(tool)) return checkRead(args.filePath ?? args.path ?? directory)
      if (tool === "edit" || tool === "write") return checkWrite(args.filePath)
      if (tool === "apply_patch") {
        const paths = patchPaths(args.patchText)
        if (!paths.length) throw new Error("OpenCode Guard: no file paths in patch")
        paths.forEach(checkWrite)
      }
    },
  }
}
