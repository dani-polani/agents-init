# set-tools-color-schemes — reference

## Why “inherit terminal” fails

TUI apps reuse the 16 ANSI slots as **roles** (directory=blue, error=red, muted=white /
bright-black). Editor `terminal.ansi*` tables are often art-directed for the integrated
terminal, not for those roles.

Typical failure modes on light UIs:

- Secondary labels vanish (ANSI “white” is near-white wash on white `panel_bg`)
- Selections / folders look purple (ANSI “blue” is violet in the editor table)
- micro looks muddy (hex theme approximated to 256 colors without truecolor)

**Method:** host terminal gets TUI-safe ANSI; app chrome gets its own hex themes.

## Semantic ANSI mapping (host terminal)

Keep hues inspired by the editor; assign by **role**:

| Idx | Role | Guidance |
|-----|------|----------|
| 0 | black | Near-black / strongest text |
| 1 | red | Real red (errors) |
| 2 | green | Readable on the theme bg |
| 3 | yellow | Ochre on light bg; brighter on dark bg |
| 4 | blue | Editor **accent** blue (folders, links) |
| 5 | magenta | Magenta / pink accent |
| 6 | cyan | Cyan readable on bg |
| 7 | white | Muted secondary text — **never** near-bg chrome |
| 8 | bright black | Mid muted / comments |
| 9–14 | bright * | Brighter variants of 1–6 |
| 15 | bright white | Soft gray or soft light — not pure `#ffffff` on light UIs |

`background` / `foreground` / cursor / selection come from editor UI tokens (`editor.*`,
status/selection accents), not from ANSI 0/7.

### Dark themes

Same roles. Raise contrast on accents; ANSI 7/15 should still separate “secondary” from
true foreground. Prefer a dark herdr base + custom overrides.

## Extracting the editor theme JSON

### Named themes

Search installed extensions for the label in `package.json` → `contributes.themes[]` →
`path`.

### UUID themes (e.g. Doki)

Example only — any UUID-based pack works the same:

1. `"workbench.colorTheme": "<uuid>"` in settings
2. Find the extension under `~/.cursor/extensions/` or `~/.vscode/extensions/`
3. Match `id` in `contributes.themes[]` → open the listed `*.theme.json`
4. Read `colors` + `tokenColors`

Minimum UI keys: `editor.background`, `editor.foreground`, selection, cursor, status /
accent-like keys, borders/sidebar surfaces. Minimum syntax: comment, keyword/storage,
string, function/method, number, type.

## herdr

Light bases include `one-light`, `catppuccin-latte`, `solarized-light`, `rose-pine-dawn`,
`kanagawa-lotus`, `gruvbox-light`, `tokyo-night-day`. Dark bases include `one-dark`,
`catppuccin`, `tokyo-night`, etc. Prefer **base + `[theme.custom]`** over `terminal` when
the goal is matching an editor.

Common custom tokens: `accent`, `panel_bg`, `surface`, `border`, `text`, `subtext`,
`red`, `green`, `yellow`, `blue`, `magenta`, `cyan`.

`subtext` must pass a contrast check on `panel_bg` (sidebar labels).

## micro color-link notes

Truecolor format:

```
color-link default "#foreground,#background"
color-link comment "italic #…"
color-link cursor-line "#softWashOnly"
color-link statusline "#fgOnAccent,#accent"
color-link selection "#fg,#selectionBg"
```

Map statement / keyword / string / identifier from editor `tokenColors`. On light
backgrounds, darken neon tokens slightly for reading comfort.

micro enables truecolor only when `MICRO_TRUECOLOR=1` (see skill + wrapper asset). Without
it, `*-tc` schemes are approximated to 256 colors.

Structural references: builtins `sunny-day`, `bubblegum`, `dukelight-tc`; community
`catppuccin-latte.micro` / mocha for dark.

## yazi

Override with hex: `[mgr]`, `[tabs]`, `[mode]`, `[indicator]`, `[status]`, `[filetype]`.
Skip regenerating the huge `[icon]` tables unless required.

Pattern: accent solid for active tabs/mode; soft selection wash for hover; filetype
directories use accent blue.

## Fonts (optional)

Color sync ≠ font sync. If asked: unset `editor.fontFamily` on Linux often falls through
to fontconfig (e.g. DejaVu). In Ghostty, `font-style = Medium` and mild
`adjust-cell-height` can feel closer to the editor than Regular alone.

## Reload cheat sheet

| Tool | Reload |
|------|--------|
| Ghostty | New window / config reload |
| herdr | `herdr server reload-config` |
| yazi | Restart yazi |
| micro | Quit and reopen (env + scheme at start) |
