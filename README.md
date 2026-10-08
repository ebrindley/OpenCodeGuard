# OpenCode Guard

Deprecated. [Agent Guard](https://github.com/ebrindley/AgentGuard) replaces
OpenCode Guard for new installations and updates. This repository and its
[v1.0.4 release](https://github.com/ebrindley/OpenCodeGuard/releases/tag/v1.0.4)
are retained for recovery.

## Migrate to Agent Guard

Requires macOS 15 or later. Quit OpenCode and follow the
[migration guide](https://github.com/ebrindley/AgentGuard/blob/main/docs/OPERATIONS.md#moving-from-opencode-guard)
from Terminal outside an agent session or sandbox.

The installer asks before importing your Guard List and keeps the permission
record needed for uninstall. A failed migration rolls back. After migration,
use Agent Guard's app or `opencode` in a new terminal.

## Recover OpenCode Guard

Run `agent-guard uninstall` before installing v1.0.4. Agent Guard uses the
imported permission record to restore settings where they still match the
values OpenCode Guard wrote; settings you changed are preserved.

The [v1.0.4 release](https://github.com/ebrindley/OpenCodeGuard/releases/tag/v1.0.4)
contains the legacy DMG and ZIP. Read the
[v1.0.4 manual](https://github.com/ebrindley/OpenCodeGuard/blob/v1.0.4/README.md)
for installation, configuration, limitations and uninstall instructions.

## License

[MIT](LICENSE). Bundled cc-safety-net retains its
[MIT license](vendor/cc-safety-net/LICENSE).
For current support, use [Agent Guard](https://github.com/ebrindley/AgentGuard).
