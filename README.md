# veteran

A self-contained Lua UI library for Roblox exploit/utility scripts. Ships a top bar, tabbed windows, a full widget set (toggles, sliders, dropdowns, color pickers, keybinds, buttons, textboxes), theming with save/load/autoload, a draggable watermark, a config export/import system, and an optional CoreGui redesign mode that replaces the native Roblox chat/backpack/player-list/emotes bar with its own hotbar and utility panels.

> Loaded by a loader script (e.g. `VeteranLoader.lua`). Do not inject this file standalone — it expects to be required/run in an environment with an executor's `getgenv`/filesystem functions available.

---

## Contents

- [Quick start](#quick-start)
- [Concepts](#concepts)
- [Windows, tabs & sections](#windows-tabs--sections)
- [Widgets](#widgets)
  - [Toggle](#toggle)
  - [Slider](#slider)
  - [Dropdown](#dropdown)
  - [Colorpicker](#colorpicker)
  - [Button](#button)
  - [Textbox](#textbox)
  - [Keybind](#keybind)
  - [Chat filter](#chat-filter)
- [Options, flags & persistence](#options-flags--persistence)
- [Themes](#themes)
- [Watermark](#watermark)
- [Notifications & confirm dialogs](#notifications--confirm-dialogs)
- [Changelog / info panel](#changelog--info-panel)
- [Feature jump / search](#feature-jump--search)
- [CoreGui redesign mode](#coregui-redesign-mode)
- [Licensing / ops backend](#licensing--ops-backend)
- [Unloading](#unloading)
- [Full API reference](#full-api-reference)

---

## Quick start

```lua
local veteran = getgenv().veteran

-- boots the UI (splash screen, top bar, all built-in panels)
veteran:boot()

-- run code once the UI has finished booting
veteran:ready(function(ui)
    local window = ui:window({ name = "configurations", tab = "Configurations" })
    local page = window:tab({ name = "main" })
    local section = page:section({ name = "example" })

    section:toggle({
        name = "silent aim",
        flag = "silent_aim",
        default = false,
        callback = function(on)
            print("silent aim:", on)
        end,
    })
end)
```

The library is a singleton stored at `getgenv().veteran`. Calling `boot()` a second time while it's already mounted is a no-op.

---

## Concepts

| Concept | Description |
|---|---|
| **Window** | A floating panel opened from the top bar (e.g. `Configurations`, `Themes`, `Environment`). Created with `veteran:window(...)`. |
| **Tab** | A named page inside a window. `window:tab({ name = "main" })`. |
| **Section** | A titled box inside a tab, placed in the left or right column. `page:section({ name = "..." })`. |
| **Flag** | A unique string key identifying a persisted option (toggle/slider/dropdown/color/text/keybind). Options with a `flag` are auto-saved and reloaded across sessions. |
| **Option meta** | Internal registry (`veteran.option_meta`) mapping every flag to its widget type, default, current key/bind, and setter — powers persistence, the keybind list, search, and "jump to feature". |

---

## Windows, tabs & sections

```lua
local window = veteran:window({
    name = "configurations",     -- window title
    tab = "Configurations",      -- ties this window to a top-bar tab
    size = UDim2.fromOffset(560, 430),
    position = UDim2.fromOffset(68, 68),
})

local page = window:tab({ name = "combat" })   -- creates or returns existing tab
local left_section  = page:section({ name = "aimbot" })                 -- left column (default)
local right_section = page:section({ name = "esp", side = "right" })    -- right column
```

- Calling `window:tab({ name = ... })` again with the same name just switches to it (`open_tab`).
- Sections auto-size vertically to their contents and stack top-to-bottom in whichever column they're placed in.
- `window:section(...)` is shorthand that adds to whatever the currently open tab is (creating a `"main"` tab if none exists yet).

---

## Widgets

All widget constructors live on a **section** object (`section:toggle{...}`, `section:slider{...}`, etc.) and share this pattern:

- `flag` *(optional)* — if given, the widget's value is registered in `veteran.options`, persisted to disk, and reloaded on next boot.
- `name` *(optional)* — display label. Falls back to a prettified version of `flag` (underscores → spaces) if omitted.
- `get` / `set` *(optional)* — custom getter/setter, used instead of the flag-backed default when you want to bind the widget to something else entirely.
- `callback` *(optional, alias `set`)* — fired whenever the value changes.

### Toggle

```lua
section:toggle({
    name = "esp",
    flag = "esp_enabled",
    default = false,
    color = { flag = "esp_color", default = Color3.fromRGB(255, 0, 0) }, -- optional attached color swatch
    callback = function(on) ... end,
})
```

### Slider

```lua
section:slider({
    name = "fov",
    flag = "fov_radius",
    min = 10,
    max = 500,
    default = 120,
    interval = 1,     -- step size; supports fractional steps (e.g. 0.01)
    suffix = "px",    -- appended to the displayed value
    callback = function(value) ... end,
})
```

Right-click (or `MouseButton2`) on a slider label/track to open a precise numeric-entry popup.

### Dropdown

```lua
-- single-select
section:dropdown({
    name = "target priority",
    flag = "priority",
    items = { "closest", "lowest health", "highest health" },
    default = "closest",
})

-- multi-select
section:dropdown({
    name = "ignore teams",
    flag = "ignored_teams",
    items = { "Red", "Blue", "Spectator" },
    multi = true,
    default = {},
})
```

### Colorpicker

```lua
section:colorpicker({
    name = "chams color",
    flag = "chams_color",
    default = Color3.fromRGB(0, 255, 140),
})
```

Opens a saturation/value square + hue slider + RGB text entry.

### Button

```lua
section:button({
    name = "reset camera",
    flag = "reset_camera",   -- optional, enables keybind assignment
    callback = function() ... end,
})
```

### Textbox

```lua
section:textbox({
    name = "webhook url",
    flag = "webhook_url",
    placeholder = "https://...",
    default = "",
    callback = function(text) ... end,
})
```

### Keybind

```lua
section:keybind({
    name = "toggle esp",
    flag = "esp_enabled",   -- binds to an existing toggle/button flag
    default = Enum.KeyCode.E,
})
```

Click the bind chip and press any key/mouse button to rebind; press **Escape** to clear. Right-click a row in the **Keybinds** panel to flip between `toggle` and `hold` mode.

### Chat filter

A prebuilt "keyword watcher" widget for logging chat matches:

```lua
page:chat_filter({
    name = "trigger words",
    side = "right",
    flag = "chat_filter_keywords",
    enabled_flag = "chat_filter_enabled",
})
```

Renders a keyword input + chip list + a live log of matching players (click a logged row to copy `DisplayName | UserId`).

---

## Options, flags & persistence

Every flagged widget writes into `veteran.options[flag]` and is described in `veteran.option_meta[flag]`. Low-level accessors:

```lua
veteran:get_option(flag)
veteran:set_option(flag, value)
```

Config is saved to **`veteran/configs/current.json`** (falls back to reading legacy `veteran/config.json`), debounced ~0.4s after the last change. You can also export/import a full config blob manually:

```lua
local json = veteran:export_config()
veteran:import_config(json)
```

UI-only flags (top bar visibility, the menu keybind, watermark toggle, etc.) are excluded from `export_config`/`import_config` — they live in the same save file but are treated as chrome, not "your script's settings".

---

## Themes

Opened from the top bar's **Themes** tab. Themes cover the full color palette plus hotbar layout (`hotbar_size`, `hotbar_spacing`) and a couple of chrome toggles (top bar autohide, "hide fullscreen exit button").

```lua
veteran:set_theme("Accent", Color3.fromRGB(120, 90, 200))
veteran:write_theme_file("my_theme")        -- veteran/themes/my_theme.json
veteran:load_theme_file("my_theme")
veteran:set_autoload("my_theme")            -- load automatically on next boot
veteran:set_autoload(nil)                   -- disable autoload
veteran:reset_theme()                       -- restore defaults
```

Theme keys: `Accent`, `Window Background`, `Window Border`, `Tab Background`, `Tab Border`, `Tab Toggle Background`, `Section Background`, `Section Border`, `Text`, `Disabled Text`, `Object Background`, `Object Border`, `Dropdown Option Background`.

---

## Watermark

A small, draggable, always-on-top label. Configurable from the **Watermark** tab: name, clock, FPS, ping — each independently toggleable. Position/anchor persist to `veteran/watermark.json` whenever you drag it.

```lua
veteran:set_watermark_opt("enabled", true)
veteran:set_watermark_opt("fps", true)
```

---

## Notifications & confirm dialogs

```lua
veteran:notification({ text = "loaded config", duration = 3 })

veteran:confirm({
    name = "reset all settings?",
    options = { "Yes", "No" },
    callback = function(choice)
        if choice == "Yes" then veteran:reset_theme() end
    end,
})
```

---

## Changelog / info panel

The **info** tab shows the version number, a scrollable changelog, and the current license role/key.

```lua
veteran:set_changelog({
    { tag = "+", text = "added silent aim", jump = { tab = "combat", sections = { "aimbot" } } },
    { tag = "-", text = "removed legacy esp" },
    { tag = "M", text = "reworked config window" },
})
```

`tag` is one of `"+"` (added, accent color), `"-"` (removed, red), `"M"` (modified, gold), or omitted for a plain note. If `jump` is supplied, clicking the entry calls `reveal_feature` to open the right tab and highlight the section.

---

## Feature jump / search

Every section/control is searchable via the search box in the **Configurations** window (matches section name, control names, flags, and page name). You can also jump to a feature programmatically:

```lua
veteran:reveal_feature({
    tab = "combat",
    sections = { "aimbot" },   -- pulses the section border/title
    flag = "fov_radius",       -- also pulses this specific control
})

-- or just open a top-bar chrome panel (Themes/Environment/etc.)
veteran:reveal_feature({ chrome = "Environment" })
```

---

## CoreGui redesign mode

Set the `CoreGui_Redesign` local at the top of the file to `true` (or toggle "rewrite coregui" in the Themes tab, dev/owner only) to have veteran take over Roblox's native chat, backpack, player list, and emotes menu — hiding the stock top bar and rendering its own hotbar (number-key tool switching) and utility flyout panels instead. With it left `false`, veteran only adds its own top bar alongside the default Roblox UI and leaves chat/backpack/players/emotes untouched.

Only users resolved as `dev`/`owner` (see [Licensing](#licensing--ops-backend)) can enable this mode at runtime.

---

## Licensing / ops backend

veteran ships with an optional Supabase-backed licensing/ops layer (`veteran:ops(action, extra)`) used for:

- resolving the caller's role (`veteran` / `dev` / `owner`) via `getgenv().veteran_session`
- an in-game "panel" tab (dev/owner only) listing other live licensed users, with join/bring actions
- a "report" dialog (game support / report another user / request dev-owner assistance) with server-side cooldowns

This is entirely optional infrastructure for products that gate features by license tier — a standalone UI consumer can ignore `veteran:ops`, `OWNER_IDS`/`DEV_IDS`, and the `panel`/report tabs entirely.

---

## Unloading

```lua
veteran:unload()
```

Disconnects every signal, destroys the ScreenGui, restores any hidden CoreGui elements, and clears `getgenv().veteran` so a fresh inject can boot cleanly.

---

## Full API reference

### Lifecycle
| Method | Description |
|---|---|
| `veteran:boot()` | Mounts and plays the splash/boot sequence. |
| `veteran:ready(fn)` | Runs `fn(veteran)` once booted (immediately if already booted). |
| `veteran:unload()` | Tears down the entire UI and its hooks. |

### Windows
| Method | Description |
|---|---|
| `veteran:window(props)` | Creates/returns a draggable window. `props.tab` links it to a top-bar tab. |
| `window:tab(props)` | Creates or switches to a named tab. |
| `window:open_tab(name)` | Switches to an existing tab. |
| `window:section(props)` | Adds a section to the current tab. |
| `window:resize(udim2)` | Resizes the window frame. |

### Sections (widget factories)
`section:toggle`, `section:slider`, `section:dropdown`, `section:colorpicker` (alias `section:color`), `section:button`, `section:textbox`, `section:keybind`, `page:chat_filter`.

### Options
| Method | Description |
|---|---|
| `veteran:get_option(flag)` / `set_option(flag, value)` | Low-level flag read/write. |
| `veteran:export_config()` / `import_config(json)` | Serialize/apply a full options+binds blob. |

### Theming
`set_theme`, `write_theme_file`, `load_theme_file`, `delete_theme_file`, `list_theme_files`, `set_autoload`, `reset_theme`.

### Misc UI
`notification`, `confirm`, `set_changelog`, `reveal_feature`.

### Chrome / redesign
`set_coregui_rewrite(on)`, `wants_coregui_redesign()`, `set_utility_open(name, on)` (`"chat" | "backpack" | "players" | "emotes"`).

---

## File layout on disk

```
veteran/
├─ themes/
│  ├─ <name>.json
│  └─ autoload.txt
├─ configs/
│  └─ current.json
├─ environment.json      -- friendly/enemy player relations
├─ watermark.json
└─ coregui_rewrite.txt
```
