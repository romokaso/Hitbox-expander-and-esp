# Changelog

All notable changes to this project are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
and the project uses [Semantic Versioning](https://semver.org/).

## [2.0.0] — 2026-10-20

The script moved from `Hitbox changer & esp` to [`HitboxEsp.luau`](HitboxEsp.luau)
so that Luau tooling (StyLua, selene, luau-lsp, CI) can see it. Settings moved to
a new file with schema version 2; settings written by 1.x are not imported.

### Fixed

- **Closing the GUI left the script running.** `ScreenGui:Destroy()` does not
  disconnect signals, so keybinds kept re-enabling hitboxes and ESP after
  "close". Closing now runs a single `unload()` that disconnects every
  connection, stops the update loop, restores all hitboxes, removes ESP objects
  and only then destroys the GUI. `unload()` is idempotent.
- **Unvalidated settings could break every subsequent launch.** The settings file
  is now sanitised field by field (type, range, keybind names), corrupt files are
  copied to `.corrupt`, and a `.bak` copy is used when the main file cannot be
  decoded.
- **Closing mutated characters it never touched.** `forceRestoreAllHitboxes`
  used to set `CanCollide = false` on every whitelisted part of every character,
  even without a snapshot. Restoring now only touches characters with a snapshot.
- **Snapshots could be captured after a resize.** A character briefly losing
  `Parent` (death lobby, round cleanup) caused the expanded parts to be
  snapshotted and later "restored" to the enlarged size. Snapshots are now keyed
  by player and character and only discarded when the character is destroyed or
  replaced.
- **Unbounded hitbox size.** Input is clamped to 1–50, rounded to one decimal,
  and non-finite values (`1e400`, NaN) are rejected. The same validation runs on
  load, so an oversized saved value cannot brick the client.
- **Running the script twice stacked two GUIs and two loops.** A single-instance
  guard uses `getgenv().HitboxESP.unload` and removes a stale GUI.
- **The window could be dragged off-screen permanently.** Dragging clamps to keep
  120 px visible, saved positions are re-clamped on start and on viewport
  changes, and Settings has a "Reset position" button.
- **Dragging leaked a connection per click.** Replaced per-click
  `input.Changed:Connect` with one global `InputChanged`/`InputEnded` pair.
- **Keybinds fired while typing.** Key handling ignores keys consumed by the game
  and keys typed into a focused text box. Binding an already-used key moves it
  instead of creating a conflict.
- **Enter in the size field did nothing.** `FocusLost` now applies the value.
- **ESP labels were blank for a frame after creation.** Labels are populated when
  the entry is created, not only on the next update tick.
- **Theme changes were animating from hard-coded colours** and the settings panel
  could be skipped by theme entries. One binding table now drives every themed
  property, including the toggle buttons and keybind rows.
- **The window drifted down by the topbar inset on every launch.** Saved positions
  are screen coordinates (`AbsolutePosition`) but were applied as `Position`,
  which excludes the 36 px `IgnoreGuiInset` offset. Positions are now converted
  with `GuiService:GetGuiInset()` in both directions.

### Changed

- Update work is throttled to 10 Hz instead of running on every `Heartbeat`, and
  part properties are only written when they differ.
- Hitbox parts use `SmoothPlastic` instead of `ForceField` (the most expensive
  client material used here) for a large performance win on populated servers.
- `Highlight.DepthMode` is set explicitly (`AlwaysOnTop`) instead of relying on an
  engine default that has changed between releases.
- Keybinds default to unbound on first run; the previously hard-coded keys are
  no longer assumed.
- Toggle state is persisted and can be re-applied on launch via the new
  **Restore on start** option (off by default).
- The settings panel scrolls with `AutomaticCanvasSize`, and the fixed 350 px
  canvas is gone.
- Startup no longer flashes the default theme or builds the GUI on screen: the
  GUI is created disabled, themed without tweens, positioned, then enabled.
- The interface scales with the viewport (`UIScale`, 0.9–1.25) so it stays
  readable on high-DPI screens and usable on small ones.
- The status line truncates instead of overflowing into the toggles.

### Added

- `tests/run.lua`: unit tests for the pure helpers (size parsing, settings
  validation, keybind encoding, window clamping, ESP text).
- `tests/smoke.lua` and `tests/mock_roblox.lua`: end-to-end tests that boot the
  whole script against a mock Roblox API (instances, signals, tweens, task
  scheduler, file system, JSON).
- `docs/ci-workflow.yml`: a ready-to-use GitHub Actions workflow that runs both
  test suites on Lua 5.4 and a StyLua formatting check.
- `LICENSE` (MIT), `CHANGELOG.md`, `.stylua.toml`, `.editorconfig`, `.gitignore`.
- README rewritten with install, usage, keybind, persistence, rig-support,
  development and troubleshooting sections; added `README.uk.md`.

### Removed

- Dead `modifiedChars` bookkeeping and the unused `HumanoidDescription` lookup.
- The 21 duplicated `task.wait`-based restore paths in favour of a shared
  snapshot module.

## [1.0.0] — 2025

- Initial release: hitbox expander, ESP, theme switch, settings panel, keybinds,
  settings persistence.

[2.0.0]: https://github.com/romokaso/Hitbox-expander-and-esp/releases/tag/v2.0.0
