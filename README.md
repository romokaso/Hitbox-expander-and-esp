<div align="center">

# 🎯 Hitbox Expander

**Hitbox expander + ESP for Roblox with a clean animated GUI**

[![Roblox](https://img.shields.io/badge/Roblox-Script-00A2FF?logo=roblox&logoColor=white)](https://www.roblox.com)
[![Lua](https://img.shields.io/badge/Lua-100%25-2C2D72?logo=lua&logoColor=white)](#)
[![Keyless](https://img.shields.io/badge/Keyless-✅-brightgreen)](#)
[![GitHub last commit](https://img.shields.io/github/last-commit/romokaso/Hitbox-expander-esp)](https://github.com/romokaso/Hitbox-expander-esp)
[![GitHub Repo stars](https://img.shields.io/github/stars/romokaso/Hitbox-expander-esp?style=social)](https://github.com/romokaso/Hitbox-expander-esp)

</div>

---

## 📖 Table of Contents

- [✨ Features](#-features)
- [📋 Requirements](#-requirements)
- [🚀 Quick Start](#-quick-start)
- [🕹️ Usage](#️-usage)
- [⌨️ Keybinds](#️-keybinds)
- [⚙️ Settings](#️-settings)
- [🧠 How It Works](#-how-it-works)
- [💾 Autosave](#-autosave)
- [❓ FAQ](#-faq)
- [📁 Repository Structure](#-repository-structure)
- [🛠️ Recent Changes](#️-recent-changes)

---

## ✨ Features

### 🎯 Hitbox Expander
- Enlarges the hitboxes of **every player except you** — making them noticeably easier to hit
- Size is set manually (minimum `1`, default `10`)
- Works with both **R6 and R15** characters — the script finds all the right parts automatically
- Smart scaling for different body parts:

| Part | Multiplier | Notes |
|---|---|---|
| `HumanoidRootPart` | ×1.0 | Fully invisible, collisions disabled |
| `Head` | ×0.8 | Team color, `ForceField` material |
| Other parts (torso, arms, legs and their segments) | ×0.7 | Team color, `ForceField` material |

- **Safe shutdown**: the original properties of every part (`Size`, `Transparency`, `CanCollide`, `Color`, `Material`, `CastShadow`) are saved and fully restored when the feature is disabled or the script is closed
- Automatically applies to new players and respawns, and skips dead characters

### 👁️ ESP
- Above each player's head: **name** (plus `DisplayName` if it differs), **distance in studs** and **HP** (`current/max`)
- Text and highlight use the player's **team color**
- Character `Highlight` with 50% fill and a full outline
- Updates **every frame**, automatically picks up new players and removes those who leave or die

### 🖥️ GUI
- Clean **260×180** interface with rounded corners and smooth animations (TweenService)
- **Draggable** by the title bar
- **Minimizable** into a compact bar
- **Dark and light themes** with smooth switching
- Closing **with confirmation** (so you don't turn it off by accident)
- Visual feedback for invalid input (the size field flashes red)

### ⚙️ Settings
- **5 customizable keybinds** (see [Keybinds](#️-keybinds))
- "Disable Transparency" option — controls hitbox part transparency
- Theme switcher
- **Autosave**: all settings are written to a file and restored on the next launch

---

## 📋 Requirements

- A **Roblox** account
- Any up-to-date script **executor**
- Autosave requires `writefile`/`readfile` support (available in most executors); without it the script still works, just without saving

---

## 🚀 Quick Start

1. Download the [`Hitbox expander`](./Hitbox%20expander) file or copy its contents
2. Launch Roblox and your executor
3. Paste the code into the executor and run it
4. The **Hitbox expander** window appears in the center of the screen — you're done! 🎉

> 💡 You can also use `loadstring`:
> ```lua
> loadstring(game:HttpGet("RAW_LINK_TO_THE_FILE"))()
> ```
> substituting the raw link to the `Hitbox expander` file in your branch of the repository.

---

## 🕹️ Usage

| Element | What it does |
|---|---|
| **"Expander Size"** field + **Apply** button | Sets the hitbox size and applies it (works even when the toggle is off — the size is simply saved) |
| **Hitbox Expander: ON/OFF** button | Toggles the hitbox expansion |
| **ESP: ON/OFF** button | Toggles the ESP |
| **⚙** button | Opens the settings panel |
| **—** button | Minimizes the window into a slim bar |
| **X** button | Closes the script (with confirmation). On close, all hitboxes are restored and the ESP is removed |

**Quick workflow:** enter a size (e.g. `15`) → press **Apply** → toggle **Hitbox Expander** on → optionally enable **ESP**.

---

## ⌨️ Keybinds

Configuration: **⚙ → Keybinds →** click the action's button → press the desired key. `Escape` cancels the assignment.

| Action | What it does |
|---|---|
| **Toggle Expander** | Toggle hitbox expansion on/off |
| **Toggle ESP** | Toggle ESP on/off |
| **Toggle GUI** | Show/hide the window |
| **Minimize** | Minimize/restore the window |
| **Apply Expander** | Apply the size from the field |

By default, no keys are bound (`None`) — set them up as you like.

---

## ⚙️ Settings

| Option | Values | Default | Description |
|---|---|---|---|
| **Theme** | Dark / Light | `Dark` | Interface theme |
| **Disable Transparency** | ON / OFF | `OFF` | `ON` — hitbox parts are completely invisible; `OFF` — semi-transparent (30% visible) |
| **Keybinds** | 5 actions | `None` | Hotkeys (see [Keybinds](#️-keybinds)) |
| **Expander Size** | ≥ 1 | `10` | Hitbox size |

All settings are applied instantly and **saved automatically**.

---

## 🧠 How It Works

- **Every frame** (`RunService.Heartbeat`) the script iterates over all players, finds their characters and scales the body parts, saving the original properties along the way. On disable/close — everything is restored to its original state.
- **ESP** creates a `BillboardGui` above the head (always on top, 3.2 studs offset) and a `Highlight` around the character; distance and HP are recalculated in real time.
- **Settings** are serialized to JSON and written to `hitbox_expander_settings.json` in the executor's workspace folder.

---

## 💾 Autosave

- Settings file: `hitbox_expander_settings.json` (in your executor's workspace folder)
- Saved values: hitbox size, theme, "Disable Transparency" and all keybinds
- Settings are restored every time the script runs
- **Resetting settings:** simply delete the `hitbox_expander_settings.json` file

---

## ❓ FAQ

**Why doesn't my own character get bigger?**
The script expands the hitboxes of *other* players — so that *you* can hit them more easily. Your own character is not affected.

**Only my client sees the changes?**
Yes, the script works client-side. In most games hits are registered with the new sizes, but in games with server-side hit validation or anti-cheat there may be no effect.

**The script doesn't work / the GUI doesn't appear.**
Make sure your executor is up to date and supports the APIs used. Some games block third-party scripts — try it in a different game.

**Why are the keybinds "None" by default?**
They are intentionally unbound so they don't conflict with game controls. Set them up in **⚙ → Keybinds**.

**What if I enter an invalid size?**
The field flashes red. The minimum size is `1`; smaller values are automatically rounded up to `1`.

**Something broke in other players' characters?**
Press **X** (close) or turn off **Hitbox Expander** — all original part properties will be restored automatically.

---

## 📁 Repository Structure

```
Hitbox-expander-esp/
├── Hitbox expander   # main script (Lua / Roblox)
└── README.md         # this file
```

---

## 🛠️ Recent Changes

- 🔄 Full rebranding: **Hitbox changer** → **Hitbox Expander** (file, GUI, settings, internal code)
- 💾 Settings save/load system with file autosave
- ⌨️ 5 customizable keybinds + UI for assigning them
- 👁️ GUI visibility toggle
- 📜 Scrollable settings panel
- 🧹 Improved hitbox restoration and character tracking
- 🎨 Visual feedback for invalid input
- 🛡️ Preservation of additional part properties (`CastShadow` and more)
- 🐞 Fixed cleanup when disabling features

---

<div align="center">

Made with ❤️ — **by: romokaso**

</div>
