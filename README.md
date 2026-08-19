# Hitbox Changer & ESP

A client-side Lua script for Roblox with a graphical interface. It creates a **"Hitbox changer & esp"** window for configuring visual character-part changes and player ESP indicators.

> ⚠️ **Important:** Using ESP, hitbox modifications, or third-party executors in games you do not own may violate Roblox's Terms of Use and a game's rules, potentially resulting in account penalties. Use this code only where you have permission, such as when testing your own experience.

## Features

### Hitbox Changer

When enabled, the script processes characters for **all players except the local player**:

- Sets `HumanoidRootPart` to the selected size.
- Sets `Head` to 80% of the selected size.
- Sets the remaining supported body parts to 70% of the selected size.
- Disables collisions on modified parts (`CanCollide = false`).
- Visually colors heads and body parts using the player's team color and applies the `ForceField` material.
- Makes the visual parts semi-transparent or fully hidden with the **Disable Transparency** option.
- Stores each part's original size, transparency, collision state, color, material, and shadow setting, then restores them when the feature is disabled or the interface is closed.

The script supports both R6 and R15 part names, including `HumanoidRootPart`, `Head`, `Torso`, arms, legs, `UpperTorso`, `LowerTorso`, and compound limb parts.

### ESP

For every other living player, the script creates:

- A `Highlight` with fill and outline colors based on the player's team.
- A label above the character (`BillboardGui`) showing:
  - Display name, when it differs from the username.
  - Username.
  - Distance to the player in studs.
  - Current and maximum health.

ESP and hitboxes are updated through `RunService.Heartbeat`, so they respond to movement, respawns, health changes, and new players joining the server.

### Interface and Settings

- Adjustable hitbox size with a minimum value of `1`.
- Hitbox and ESP toggles.
- Light and dark themes.
- Window minimization, close confirmation, and title-bar dragging.
- Assignable hotkeys for:
  - Toggling Hitbox.
  - Toggling ESP.
  - Showing or hiding the interface.
  - Minimizing the window.
  - Applying the selected hitbox size.

## Saved Settings

The script saves the following values in `hitbox_settings.json`:

- Hitbox size.
- Selected theme.
- **Disable Transparency** setting.
- Assigned hotkeys.

Settings persistence uses `writefile`, `readfile`, and `isfile`. These are not standard Roblox APIs, so saving works only in environments that provide those functions. If they are unavailable, the interface and core functionality still initialize, but settings are not retained between runs.

## Technical Notes

- The script runs on the client: it creates a `ScreenGui` in the local player's `PlayerGui` and changes locally accessible character objects.
- Modern Roblox games generally validate real hit detection and damage on the server. As a result, changing part sizes on the client does not guarantee an effect on gameplay mechanics.
- The source does not load external code, make HTTP requests, teleport players, or collect credentials. `HttpService` is used only to encode and decode the local JSON settings file.

## Files

| File | Description |
| --- | --- |
| `Hitbox changer & esp` | Main Lua script: interface, ESP, hitbox handling, and settings. |
| `README.md` | Project documentation. |
