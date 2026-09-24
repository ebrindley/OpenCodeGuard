# OpenCode Guard

Guardrails for [OpenCode](https://opencode.ai) on macOS. Agents keep full tool permissions and broad read access, but can only change or delete files in folders you allow, can never touch folders you deny, and cannot edit the guard itself.

No dependencies beyond macOS 15 or later. No admin password.

## Install

1. Download `OpenCodeGuard.dmg` (or `.zip`) from `dist/` and open it.
2. Double-click **Install OpenCode Guard**. macOS blocks unsigned downloads the first time: open **System Settings → Privacy & Security** and click **Open Anyway**.
3. Choose your projects folder. At the end, click **Edit List** to review your allow and deny list.

From a terminal: `zsh install.sh` in a clone of this repository.

Then start OpenCode with **OpenCode Guarded** (in `~/Applications`, drag it to the Dock) or type `opencode` in a new terminal window.

## The list

`~/OpenCode Guard/Guard List.txt` — one folder or file per line under a heading. Drag items in from Finder or type paths starting with `/` or `~`. Changes apply the next time OpenCode starts.

| Heading | Agents may |
|---|---|
| `ALLOW` | read, create, change, delete inside (the folder itself cannot be removed or renamed) |
| `READ ONLY` | read and search only |
| `DENY` | nothing: no reading, searching, changing or deleting |

DENY always wins. Between ALLOW and READ ONLY, the more specific path wins. Folders above a DENY or READ ONLY entry cannot be renamed or removed. `/`, your home folder, `~/Library`, `~/.config` and `~/.local` cannot be allowed as a whole.

`~/OpenCode Guard/last-launch.log` shows what applied at the last launch, lines that were skipped or refused, and the locations OpenCode can always write for itself: its data and state folders, caches, npm and Bun caches, and temp folders.

## How it works

- **Sandbox.** OpenCode (CLI and Desktop) runs under a macOS Seatbelt profile built from the list at each launch. Every process OpenCode starts inherits it. Writes are denied everywhere except ALLOW folders and what OpenCode itself needs. DENY blocks reads too. Always protected, including through symlinks: the guard, the list, OpenCode's global config, any project `.opencode` folder or `opencode.json` (these load code at the next start), cc-safety-net's rules, shell startup files and LaunchAgents. Launching apps, `osascript`, `osacompile`, `codesign`, `launchctl` and `sudo` are blocked.
- **Plugin.** Refuses edits and reads that the list forbids with a clear message, before the sandbox has to, and runs **[cc-safety-net](https://github.com/kenryu42/claude-code-safety-net)** (bundled, MIT), which blocks destructive shell commands such as `git reset --hard`, force pushes and recursive `rm`. If OpenCode was started without the guard, every tool that touches files or runs commands is refused. It registers an `opencode_guard_status` tool; the installer's self-test starts OpenCode inside the guard and checks that it is present.

## Limits

- Anything inside an ALLOW folder can be deleted. Keep backups and push your git work.
- Agents cannot edit project `.opencode` folders or `opencode.json` files; do that yourself.
- Folder names under DENY remain visible in their parent's listing.
- A program an agent compiles itself can still send Apple Events. Existing services outside the sandbox (for example Docker, remote MCP servers) are outside its reach.
- Opening links from the Desktop app is blocked while guarded. Sign in to providers by opening OpenCode once without the guard; tools stay disabled in that mode.
- The Desktop app's built-in updater cannot install while guarded. Update it without the guard.
- `opencode --pure` or a custom config directory skips the plugins; the sandbox still applies when launched through the guard.
- Automation that runs OpenCode outside the guard on purpose can set `OPENCODE_GUARD_BYPASS=1`.

## Uninstall

`zsh ~/Library/Application\ Support/OpenCodeGuard/uninstall.sh` — removes everything except your list. The installer sets `edit`, `bash` and `external_directory` to allow (keeping any finer rules); uninstall restores each one it changed unless you have changed it since.

## Development

- `zsh test/test.sh` — installs into a throwaway home, checks list parsing, the sandbox, the plugin and the OpenCode self-test, then uninstalls. Runs outside any sandbox; needs `node` and the `opencode` CLI.
- `zsh build.sh` — builds `dist/OpenCodeGuard.dmg` and `dist/OpenCodeGuard.zip`.

## License

MIT. Bundles cc-safety-net 2.4.6 (MIT, `vendor/cc-safety-net/LICENSE`).
