# Hitbox ESP

A client-side hitbox expander and ESP for Roblox, shipped as a single Luau file
with a compact GUI.

**English** · [Українська](README.uk.md)

> [!WARNING]
> This script only changes objects on **your own client**. It does not change
> server-side hit detection, damage or physics. Using it in a game may violate
> that game's rules or the Roblox Terms of Use, and can get your account
> moderated or banned. Use it at your own risk, preferably in a private server.
> The authors provide no warranty of any kind.

## Features

- **Hitbox expander** — resizes the character parts of every other player on
  your client, with a configurable size from 1 to 50 studs.
- **ESP** — name, display name, distance in studs and health, plus a team-coloured
  `Highlight`. Labels and highlights update on a throttled 10 Hz loop.
- **Exact restore** — every touched property (`Size`, `Transparency`,
  `CanCollide`, `Color`, `Material`, `CastShadow`) is snapshotted per character
  and restored when you turn the feature off, respawn, or close the script.
- **Clean GUI** — dark/light themes, minimize, draggable window that can never be
  dragged off-screen, settings panel, confirmation before closing.
- **Persistent settings** — size, theme, keybinds, toggles and window position are
  saved between sessions when the executor supports the file API.
- **Five configurable keybinds** — toggle hitbox, toggle ESP, toggle GUI,
  minimize and apply. Bind conflicts are resolved automatically.
- **Safe lifecycle** — closing unloads everything (connections, loops, GUI,
  highlights) and re-running the script replaces the previous instance instead
  of stacking a second one.

## Requirements

| Requirement | Notes |
| --- | --- |
| Roblox client with a Luau executor | The script is local-only; it never talks to a server. |
| `Highlight` support | Added to Roblox in 2021; any current client has it. |
| `writefile` / `readfile` / `isfile` | Optional. Without them the GUI still works, but shows `Persistence: unavailable`. |
| Classic R6 or R15 rig | Parts are matched by name (`HumanoidRootPart`, `Head`, `UpperTorso`, …). Custom rigs with renamed parts are not supported. |

## Install

Copy [`HitboxEsp.luau`](HitboxEsp.luau) into your executor and run it, or use:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/romokaso/Hitbox-expander-and-esp/main/HitboxEsp.luau"))()
```

The window opens in the centre of the screen. Closing it from the GUI restores
every hitbox and removes all ESP objects.

## Usage

| Control | What it does |
| --- | --- |
| **Hitbox size** + **Apply** | Sets the part scale. Values are clamped to 1–50 and rounded to one decimal. Pressing <kbd>Enter</kbd> in the field also applies. |
| **Hitbox: ON/OFF** | Expands or restores every other player's hitbox. |
| **ESP: ON/OFF** | Adds or removes name/distance/health labels and highlights. |
| **⚙** | Opens settings: theme, hide hitbox parts, restore on start, keybinds, reset position. |
| **_** | Minimizes to the title bar. |
| **X** | Asks for confirmation, then unloads the script. |

### Keybinds

Keybinds start unbound. To bind one:

1. Open **Settings**.
2. Click the bind button next to an action.
3. Press the key you want.

- <kbd>Backspace</kbd> or <kbd>Delete</kbd> clears the bind.
- <kbd>Escape</kbd> cancels listening.
- A key can only belong to one action. Binding a key that is already used moves
  it to the new action.
- Binds are ignored while the game consumes the key (chat, menus) or while a text
  box has focus.
- Binds keep working while the GUI is hidden; that is how you bring it back if
  you bound the GUI toggle.

### Settings and files

Settings live in the executor workspace:

| File | Purpose |
| --- | --- |
| `hitbox_esp_settings.json` | Current settings (schema version 2). |
| `hitbox_esp_settings.json.bak` | Previous good settings, written on every save. |
| `hitbox_esp_settings.json.corrupt` | A copy of a settings file that failed to decode, kept for debugging. |

Every value is validated and clamped on load. A corrupt or hand-edited file
falls back to defaults (or the backup) instead of breaking startup.

**Restore on start** re-enables the saved Hitbox/ESP toggles on the next launch.
It is off by default, so a fresh session never starts expanding hitboxes on its
own.

## Supported rigs

- R6: `HumanoidRootPart`, `Head`, `Torso`, `Left Arm`, `Right Arm`, `Left Leg`,
  `Right Leg`.
- R15: `HumanoidRootPart`, `Head`, `UpperTorso`, `LowerTorso`,
  `LeftUpperArm`, `LeftLowerArm`, `LeftHand`, `RightUpperArm`, … (all 15 parts).

Parts are looked up by name, only direct children of the character model are
touched, and parts that are not present are skipped. Skinned meshes, custom rigs
and accessories are not resized.

## Development

```bash
stylua .                    # format (StyLua 2.x)
lua5.4 tests/run.lua        # pure-helper unit tests
lua5.4 tests/smoke.lua      # end-to-end tests against a mock Roblox API
```

No Roblox installation is needed for either test suite. `docs/ci-workflow.yml`
contains a ready-to-use GitHub Actions workflow that runs both suites on Lua 5.4
and checks formatting with StyLua; copy it to `.github/workflows/ci.yml` to
enable it.

Optional static analysis, if you have the tools installed:

```bash
selene generate-roblox-std   # once, writes roblox.toml
selene .
luau-lsp analyze --definitions=globalTypes.d.luau HitboxEsp.luau
```

### Project layout

```
HitboxEsp.luau            the script (single file, sectioned)
tests/run.lua             unit tests for the pure helpers
tests/smoke.lua           end-to-end tests (UI, toggles, ESP, persistence, unload)
tests/mock_roblox.lua     minimal Roblox API mock used by the smoke tests
docs/ci-workflow.yml      ready-to-use CI workflow (tests + formatting)
```

### Editing the script

`HitboxEsp.luau` is organised in numbered sections. The block between
`-- >>> PURE BEGIN` and `-- <<< PURE END` must stay free of Roblox APIs: the unit
tests load exactly that block, and a test fails if it references `game`,
`Instance`, `Enum`, `task` and friends.

The smoke tests boot the whole file against `tests/mock_roblox.lua`, which
implements the parts of the Roblox API the script uses: instances and their
`Parent` bookkeeping, signals, tweens, a `task` scheduler, an in-memory file
system and a small JSON codec. When you use a new Roblox API, extend the mock in
the same commit.

### Version bumps

1. Update `SCRIPT_VERSION` in `HitboxEsp.luau`.
2. Add an entry to [`CHANGELOG.md`](CHANGELOG.md).
3. Tag the release (`v2.0.0`) so users can pin a known-good build.

## Troubleshooting

| Symptom | Cause / fix |
| --- | --- |
| Settings are not remembered | Your executor has no file API. The Settings panel shows `Persistence: unavailable`. |
| Settings reset after editing the file by hand | The file must be a JSON object. Invalid files are copied to `.corrupt`, then defaults or the backup are used. |
| The window is off-screen | Dragging always keeps 120 px visible, saved positions are re-clamped on start, and **Settings → Reset position** re-centres it. |
| Nothing changes on a custom rig | Parts are matched by name; renamed or skinned parts are skipped by design. |
| Two windows after running the script twice | The second run asks the first copy to unload and removes a stale GUI. If an old version of the script is still running, rejoin the server. |
| ESP labels missing | Your client version has no `Highlight`/`BillboardGui` support, or the player is dead. |

## License

[MIT](LICENSE) © romokaso
