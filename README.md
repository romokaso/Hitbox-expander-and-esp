# Universal Roblox Hitbox Changer & ESP

A single-script Roblox tool with a clean, animated GUI. It lets you change the
hitbox size of any player and see other players through walls with a team-colored
ESP overlay — no keys required by default.

## Features

- **Hitbox Changer** — set a custom hitbox size for yourself (or any tracked
  player) and apply it instantly.
- **ESP** — see every other player through walls:
  - Name (`@Username`) and display name (when it differs)
  - Live distance in studs
  - Health (`HP / Max HP`)
  - Team-colored `Highlight` fill + outline
  - Auto-cleans when a player dies or respawns
- **Clean animated GUI** — tweened windows, rounded corners, drag to move.
- **Dark / Light theme**.
- **Minimize, Settings and Close** buttons in the title bar.
- **Settings panel** (scrollable) with:
  - Theme picker (Dark / Light)
  - "Disable Transparency" toggle
  - 5 customizable keybinds (see below)
- **Keyless** — every action is reachable from the GUI; keybinds are optional.
- **Settings persistence** — your size, theme, transparency and keybinds are
  auto-saved to `hitbox_settings.json` and restored on the next run.

## Requirements

- A Roblox executor/injector with `writefile`, `readfile` and `isfile` support
  (the settings system depends on them; the tool degrades gracefully if they
  are unavailable).

## Usage

1. Load the `Hitbox changer & esp` script in your executor while in a game.
2. Use the GUI that appears in the center of the screen:
   - Enter a **hitbox size** and press **Apply**.
   - Toggle **Hitbox** and **ESP** on/off.
   - Open **⚙ Settings** to change the theme, disable transparency, or set keybinds.
3. To rebind a key, click its row in Settings and press the desired key
   (Esc cancels). Bindings are saved automatically.

### Default keybinds

All keybinds are **unbound (`None`)** by default and can be set from Settings:

| Action        | Description                              |
| ------------- | ---------------------------------------- |
| Toggle Hitbox | Turn the hitbox changer on/off           |
| Toggle ESP    | Turn the ESP overlay on/off              |
| Toggle GUI    | Show/hide the whole interface            |
| Minimize      | Collapse the window to the title bar     |
| Apply Hitbox  | Apply the size currently in the box      |

## Notes

- Settings are written to `hitbox_settings.json` in the executor's workspace
  folder and persist between game sessions.
- The script tracks characters automatically, so hitboxes and ESP stay attached
  when players respawn.
