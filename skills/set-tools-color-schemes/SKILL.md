---
name: set-tools-color-schemes
description: >-
  Sync Ghostty, herdr, yazi, and micro themes to match a VS Code / Cursor editor
  theme using per-tool color configs (not “inherit terminal”). Use when the user
  asks to match terminal/TUI colors to the editor, fix broken light or dark themes
  across tools, set up tool color schemes, or debug micro truecolor / herdr sidebar
  contrast / ANSI role mismatches.
---

# set-tools-color-schemes

Unify how the **editor** and the **terminal stack** look by applying one methodology:
extract a palette from the editor, then write a **dedicated theme for each tool**.

Do not rely on “use the terminal palette” / `theme = "terminal"` for app chrome
(sidebars, status bars, file lists). Light TUIs especially break under that approach.

Default Linux targets:

| Tool | Config |
|------|--------|
| Ghostty | `~/.config/ghostty/config` or `config.ghostty` + `themes/<Name>` |
| herdr | `~/.config/herdr/config.toml` |
| yazi | `~/.config/yazi/theme.toml` |
| micro | `~/.config/micro/settings.json` + `colorschemes/*-tc.micro` |

Adapt paths if the user uses another terminal or editor; the method stays the same.

## Methodology

### Principle 1 — One source palette, many consumers

1. Take **UI colors** from the editor (background, foreground, accent, selection, borders).
2. Take **syntax colors** from editor token colors (for micro / previews).
3. Treat editor `terminal.ansi*` as **optional hints only**. They are often art-directed
   and do not match the roles TUIs expect.

Build one shared palette document (even mentally): `bg`, `fg`, `accent`, `surface`,
`border`, `muted`, `selection`, `red/green/yellow/blue/magenta/cyan`. Every tool maps
*from that palette* into its own config format.

### Principle 2 — Semantic ANSI in the host terminal

ls, micro `simple`, and many CLIs assume:

| Role | Expected meaning |
|------|------------------|
| blue | directories / links |
| red | errors / danger |
| green | success / exec |
| yellow | warnings |
| white / bright-black | secondary text / chrome |

Editor themes sometimes put purple in “blue”, pink in “red”, or near-white UI wash in
“white”. For Ghostty (or any host), **remap by role**: keep the editor’s *hues* where
possible, but assign them to the **correct indices**. On light backgrounds, ANSI 7 and 15
must stay **readable muted grays**, never almost-white chrome.

Details: [reference.md](reference.md).

### Principle 3 — App chrome gets hex, not ANSI names

herdr and yazi should use **explicit `#rrggbb`** (or a light/dark base + custom overrides).
Named colors like `"blue"` / `"gray"` resolve through the host ANSI table and drift when
you change Ghostty.

### Principle 4 — Respect each tool’s footguns

| Tool | Hard rule |
|------|-----------|
| Ghostty | Prefer a named theme file under `themes/`; comment old experiments, append new |
| herdr | Prefer a light/dark **base** + `[theme.custom]` over `theme = "terminal"` for chrome |
| yazi | Hex in `theme.toml` for mgr/tabs/status/filetype; reopen after edits |
| micro | Hex / `*-tc` schemes need `MICRO_TRUECOLOR=1` or colors look muddy and wrong |

## Workflow

```
- [ ] 1. Identify editor theme + extract palette (UI + tokens)
- [ ] 2. Host terminal theme (bg/fg/cursor/selection + semantic ANSI)
- [ ] 3. herdr base + [theme.custom] hex
- [ ] 4. yazi theme.toml hex
- [ ] 5. micro *-tc + truecolor enabled
- [ ] 6. Reload / reopen and visually verify each surface
```

### 1. Extract the editor palette

Read:

- `~/.config/Cursor/User/settings.json`
- `~/.config/Code/User/settings.json`

Resolve `workbench.colorTheme` (label or UUID → theme JSON in the extension). Extract:

- `editor.background`, `editor.foreground`
- accent / status / selection / border / sidebar surfaces
- `tokenColors` for syntax (micro)
- optionally `terminal.ansi*` (hints only)

Also note `editor.fontFamily` if the user cares about matching type (color sync does not
require font sync).

How to resolve UUID themes and read JSON: [reference.md](reference.md).

### 2. Host terminal (Ghostty)

1. Create `~/.config/ghostty/themes/<Theme Name>`.
2. Comment old `theme =` / font lines in the active config; append the new block (keep history unless asked to delete).
3. Set bg/fg/cursor/selection from the palette.
4. Fill ANSI 0–15 **by semantic role** ([reference.md](reference.md)).
5. Verify: `ghostty +show-config | rg '^(theme|background|foreground|palette)'`

### 3. herdr

Pick a base that matches polarity (`one-light` / a dark built-in), then override tokens:

```toml
[theme]
name = "one-light"   # or a dark base for dark editors; avoid "terminal" for chrome match
auto_switch = false

[theme.custom]
accent = "#…"
panel_bg = "#…"
surface = "#…"
border = "#…"
text = "#…"
subtext = "#…"       # must remain readable on panel_bg
red = "#…"
green = "#…"
yellow = "#…"
blue = "#…"          # true blue role, not whatever ansiBlue was
magenta = "#…"
cyan = "#…"
```

Reload: `herdr server reload-config`

### 4. yazi

Write `~/.config/yazi/theme.toml` with hex `fg`/`bg` for mgr, tabs, mode, indicator,
status, and filetype rules. Reopen yazi after changes.

### 5. micro

1. `~/.config/micro/colorschemes/<name>-tc.micro` (`-tc` = truecolor convention).
2. `settings.json`: `"colorscheme": "<name>-tc"`.
3. Enable truecolor — micro has it **off by default**. Best: install
   [assets/micro-wrapper.sh](assets/micro-wrapper.sh) as `~/.local/bin/micro` (ahead of
   `/usr/bin` on `PATH`). Also export `MICRO_TRUECOLOR=1` in shell / Ghostty `env` /
   `~/.config/environment.d/` as belt-and-suspenders.
4. Light themes: `cursor-line` is **one background color** (soft wash from the palette).
   A `"fg,bg"` pair often becomes a solid dark bar.

Syntax mapping notes: [reference.md](reference.md).

### 6. Verify

Check each surface against the editor: bg polarity, accent, readable secondary text,
directories look blue (not random purple), micro is not muddy/dusty.

If micro is wrong: confirm `MICRO_TRUECOLOR=1` in its process environ and that PATH hits
the wrapper; reopen the pane.

## Do / don’t

| Do | Don’t |
|----|--------|
| Share one palette; translate per tool | Expect one “inherit terminal” setting to fix everything |
| Semantic ANSI roles in the host | Blind-copy editor `terminal.ansi*` |
| Hex for herdr / yazi / micro chrome | Named `"blue"`/`"gray"` when matching a specific editor |
| `*-tc` + `MICRO_TRUECOLOR=1` | Hex micro theme without truecolor |
| Soft current-line wash on light UIs | Dark full-width cursor-line bars |
| Comment & append old Ghostty lines | Wipe the user’s theme experiments unasked |

## Example (optional)

Matching a character theme such as Doki “Satsuki Light” is a valid application of this
method: resolve UUID → extract `colors`/`tokenColors` → semantic Ghostty ANSI → herdr
`one-light` + custom → yazi/micro hex. The theme name is incidental; the steps are not.

## Additional resources

- ANSI roles, theme extraction, micro color-links: [reference.md](reference.md)
- micro truecolor wrapper: [assets/micro-wrapper.sh](assets/micro-wrapper.sh)
