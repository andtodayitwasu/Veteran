# Menu / Pulsehack UI Library

A self-contained Drawing/Instance-based UI framework for Roblox executor scripts. It builds a full windowing system (windows, tabs, sections, groupboxes, and ~15 element types) on top of raw `Instance.new` calls, ships its own theme engine, config (flag) save/load system, notification/watermark/keybind-list overlays, and filesystem-backed persistence (fonts, images, configs, themes, `.lua` scripts).

The library is obfuscator-aware (LPH_* stubs at the top let it run un-obfuscated during development) and expects to run inside an executor environment with `getgenv`, filesystem, and `hookfunction`-class APIs available.

## Requirements

The script assumes an executor exposing (non-exhaustive):

- Filesystem: `readfile`, `writefile`, `isfile`, `listfiles`, `delfile`, `isfolder`, `makefolder`, `loadfile`
- Environment: `getrenv`, `getgenv`, `setthreadidentity`
- Hooking: `hookfunction`, `hookmetamethod`
- Misc: `request`, `checkcaller`, `isrbxactive`, `getcustomasset`, `sethiddenproperty`, `mousemoverel`, `crypt.base64.decode`

If any of these are missing at runtime the corresponding features (config persistence, custom fonts/images, keybind blocking, etc.) will error — the library does not feature-detect around them.

## Loading

The file is a single chunk that returns the `Menu` table:

```lua
local Menu = loadstring(YourSourceString)()
-- Menu.Library is the public API surface once initialization has run
local Library = Menu.Library
```

Initialization happens automatically at the bottom of the script — it builds `Menu`, calls `Menu.Init(Library)`, and disables the Roblox CoreGui/topbar. There is no separate "New()" call to make; loading the script is enough.

Two globals are also set for convenience/back-compat: `getgenv().Menu` and `_G.Menu`.

## Core object model

```
Menu (module-level singleton)
└─ Library                      -- Library:Window(), Library:Notify(), Library:Card(), Library:Dock(), Library:SetTheme(), Library:Fade(), Library:AddAccent(), Library:Find()
   └─ Window  (Library:Window)  -- Window:Tab(), Window:Watermark(), Window:KeybindsList(), Window:SpectatorsList(), Window:CloseContent(), Window:Find()
      └─ Tab  (Window:Tab)      -- Tab:Section(), Tab:MultiSection(), Tab:Open()
         └─ Section (Tab:Section) -- Section:Groupbox(), Section:<Element>(), Section:Open(), Section:Update()
            └─ Groupbox (Section:Groupbox)
               └─ Group (Groupbox:Add) -- also accepts every Section:<Element>() call
                  └─ Elements: Toggle, Slider, Dropdown, Button, TextBox, CodeBox, Label,
                                List, ExpandableToggle, ExpandableLabel, Colorpicker, Keybind
```

Everything below `Section` shares the same `Sections` metatable, so a `Groupbox` "Group" and a plain `Section` both expose the same element-creation methods (`:Toggle{}`, `:Slider{}`, etc.). `Colorpicker` and `Keybind` are attached to an existing element (e.g. a Toggle) rather than created standalone — see below.

All creation methods take a single `Parameters` table and return the created object (plus, for a couple, a second value). Missing fields fall back to sensible defaults baked into the function.

## Quick start

```lua
local Library = Menu.Library

local Window = Library:Window({
    Name = "My Script",
    Size = Vector2.new(500, 450),
    Bind = Enum.KeyCode.RightAlt, -- toggle key, or false/"None" to disable
    HasTabs = true,
    Visible = true,
})

local Tab = Window:Tab({ Name = "Main", Opened = true })

local Section = Tab:Section({ Name = "Combat", Side = "Left", Size = 300 })

Section:Toggle({
    Name = "Silent Aim",
    Default = false,
    Flag = "SilentAim",     -- optional, used by Menu.Config save/load
    Category = "Combat",    -- optional grouping for the flag table
    Callback = function(Value)
        print("Silent Aim:", Value)
    end,
})

Section:Slider({
    Name = "FOV",
    Min = 0, Max = 500, Default = 100,
    Flag = "FOV", Category = "Combat",
    Callback = function(Value) print(Value) end,
})

Library:Notify({ Text = "Script loaded!", Time = 3 })
```

## `Library` — top level API

| Method | Parameters | Notes |
|---|---|---|
| `Library:Window(params)` | `Name`, `Size` (`Vector2` or `UDim2`), `Bind` (KeyCode, default `RightAlt`; `false`/`"None"` disables), `Callback`, `HasTabs`, `Visible`, `Disabled` | Creates and returns a top-level window. Registers it in `Library.Windows`. |
| `Library:Notify(params)` | `Text`, `Time` (seconds, default 3) | Slides a toast into the global notification tray. |
| `Library:Card(params)` | `Parent`, `Position`, `Size`, `Draggable`, `Invisible`, `Text`, `Fade` | Low-level themed panel primitive; used internally by `Notify`/`SpectatorsList`, usable directly for custom overlays. |
| `Library:Dock(params)` | `Windows` (table), `Text` | Builds a top-of-screen dock/taskbar strip. |
| `Library:AddAccent(object, zIndex?, offset?, vertical?)` | — | Draws the two-tone accent line used throughout the UI; returns the two accent Frames. |
| `Library:SetTheme(newTheme, indexes, keys?)` | `indexes` is `"All"` or a table of theme keys to restrict the repaint to | Repaints every registered `Library.Colors[instance]` entry from the (new) theme table. |
| `Library:Find(name)` | — | Returns a registered `Window` by `Name`, plus its index. |
| `Library:Fade(self, visible)` | — | Generic show/hide fade helper used by Windows, Watermark, KeybindsList, SpectatorsList, Cards. |

## `Window` methods

| Method | Parameters | Notes |
|---|---|---|
| `Window:Tab(params)` | `Name`, `Opened` | Only meaningful when the window was created with `HasTabs = true`; adds a tab button + content area. |
| `Window:Watermark(params)` | `Text`, `Enabled` | One watermark per window; `Watermark:SetText()`, `:Set(position)`, `:Get()`, `:Enable(bool)`. |
| `Window:KeybindsList(params)` | `Enabled` | Floating list of active keybinds; `:Add(keybind)`, `:Remove(...)`, `:Enable(bool)`. |
| `Window:SpectatorsList(params)` | `Enabled` | Floating spectator/name list; `:Add(name)`, `:Remove(...)`, `:Clear()`. |
| `Window:CloseContent(content?)` | — | Closes the currently open Tab/Section (or a specific content list). |
| `Window:Find(name)` | — | Finds a child Tab by name. |

When `HasTabs = false`, the window behaves like a single implicit tab/section container (its metatable falls back to `Tabs`/`Windows` methods directly), so you can call `Window:Section({...})` on it without creating an explicit Tab.

## `Tab` methods

| Method | Parameters |
|---|---|
| `Tab:Section(params)` | `Name`, `Side` (`"Left"`/`"Right"`/`"Fill"`), `Fill` (bool), `Offset`, `Size` |
| `Tab:MultiSection(params)` | `Name`, `Side`, `Fill`, `Sections` (array of tab names, default `{"Neutral","Priority","Friendly","Local"}`), `OpenIndex`, `Offset`, `Size` — returns a tabbed container whose `:Add(name, opened)` yields further `Section`-like objects |
| `Tab:Open()` | Switches the window's visible content to this tab |

## `Section` / `Groupbox` methods

| Method | Notes |
|---|---|
| `Section:Groupbox(params)` | `Groups` (array of `{Name, Image, Size}` icon-tab groups), `OpenIndex`. Returns `(Groups, Groupbox)`. |
| `Groupbox:Add(name, image, size, opened)` | Adds one icon-tab group (returns nothing; access via `Groupbox:Find(name)`). |
| `Groupbox:Find(name)` / `Groupbox:Remove(name)` | — |
| `Section:Open()` / `Section:Update()` | Manual visibility/layout control (elements normally call this for you). |

Every `Section` and every `Groupbox` "Group" exposes the full element set below.

## Element creators (`Section:<Name>(params)`)

Common optional parameters across most elements: `Flag` (string key for save/load), `Category` (string key to nest the flag under), `Hidden`, `Unsafe` / `Indev` / `Blocked` (recolor the label to warn/annotate), `Exclude` (excludes the flag from `Menu.Config("Get"/"Load")`).

| Element | Key parameters | Instance methods |
|---|---|---|
| `Toggle` | `Name`, `Default`, `Callback(value)` | `.Get()`, `.Set(bool, fire?)` |
| `Slider` | `Name`, `Min`, `Max`, `Default`, `Prefix`, `Decimals`, `Specials`, `Callback(value)` | `.Get()`, `.Set(value, fire?)`, `.SetMax(max)`, `.Refresh()` |
| `Dropdown` | `Name`, `Options` (array), `Default` (string, or array for multi-choice), `Min` (min selections), `Size`, `Callback(value)` | `.Get()`, `.Set(value)`, `.Open()`, `.Close()`, `.Update()`, `.Refresh()` |
| `Button` | `Name`, `Confirm` (require a second click), `CallbackText` (temporary label swap), `Callback(...)` | `.Activate()`, `.GetChosen()` |
| `TextBox` | `Name`, `Placeholder`, `Default`, `ResetText`, `ResetOnSubmit`, `RequireSubmit`, `Callback(text)` | `.Get()`, `.Set(string)` |
| `CodeBox` | `Default` (code string), `Size` (px height) | `.Get()`/`.GetText()`, `.Set()`/`.SetText()`, `.UpdateLines()`, `.UpdateSize()`, `.GetLineNumber()` |
| `Label` | `Text`, `Icon` | `.Get()`, `.Set()`, `.SetText()` |
| `List` | `Options` (map of `name -> {col1, col2, col3, ...}`), `Rows` (column headers), `Default`, `Clickable`, `Filter(fn)`, `Added(fn)`, `Callback(...)`, `Size` | `.Add()`, `.Remove()`, `.Find()`, `.Empty()`, `.Sort()`, `.SetValue(index)`/`.GetValue()`, `.SetValues()`/`.EditValue()`/`.EditValues()`, `.ShowValues()` |
| `ExpandableToggle` | `Name`, `Default`, `Opened`, `Size`, `Callback(value)` | `.Get()`, `.Set()`, `.Expand()`, `.Collapse()`, `.SetSize()` |
| `ExpandableLabel` | `Text`, `Opened`, `Size`, `Icon` | `.Get()`, `.Set()`, `.SetText()`, `.Expand()`, `.Collapse()` |

## Sub-elements (attached to an existing element via `Elements.<Name>`)

These decorate an element you already created (they read `Self.Section`/`Self.Frame` from the host):

| Method | Key parameters | Instance methods |
|---|---|---|
| `Elements.Colorpicker(host, params)` | `Color` (Color3), `Side`, `Transparency` (number, enables an alpha slider), `Callback(color, transparency?)` | `.Get()`, `.Set()`, `.FromRGB()`, `.Refresh()`, `.Open()/.Close()/.Show()/.Hide()`, `.Update()` |
| `Elements.Keybind(host, params)` | `Default` (KeyCode/UserInputType), `Mode` (`"Toggle"`, `"Held"`, `"Always On"`, `"Off Hold"`), `Modes` (allowed list), `Activated(fn)`, `Changed(fn)` | `.Get()`, `.Set()`, `.Open()/.Close()`, `.SetPickable()`, `.SetKeyFromInput()`, `.Shorten()`, `.Updated()` |
| `Elements.Show(self)` / `.Hide(self)` / `.Remove(self)` | — | Generic visibility/teardown for any element |

## Config (flag) persistence — `Menu.Config(action, method)`

Every element created with a `Flag` (optionally nested under `Category`) is tracked in a global `Flags` table. `Menu.Config` reads/writes that table to `<BasePath>/Configs/<name>.cfg` as JSON.

| Action | Arguments | Behavior |
|---|---|---|
| `"Get"` | — | Returns a JSON string of every flagged element's current value (skips `Exclude`d ones). |
| `"New"` / `"Save"` | `Method` = config name | Writes the current flag state to disk. |
| `"Load"` | `Method` = config name or raw JSON string | Reads a saved config and calls `.Set(value)` on every matching flag. |
| `"Reset"` | `Method` = config name | Overwrites the file with `{}`. |
| `"Delete"` | `Method` = config name | Deletes the file. |
| `"List"` | — | Returns all `.cfg` file names in the Configs folder. |
| `"Load Autoload"` / `"Set Autoload"` | `Method` = config name | Reads/writes a per-`Menu.Game` autoload pointer in `Configs/AutoLoad.json`. |

## Theme persistence — `Menu.ConfigTheme(action, method, other?)`

Mirrors `Menu.Config` but for the `Theme` table (colors are serialized as `{R, G, B, "IsRGB"}`), stored under `<BasePath>/Themes/<name>.json`. `"Load"` calls `Library:SetTheme(..., "All")` to repaint everything immediately.

## Folder layout

On load the library expects/creates a `Pulsehack/` root (configurable via the internal `BasePath` constant) with subfolders: `Fonts`, `Images`, `Configs`, `Luas`, `Themes`, and `Sounds/{Hitsounds,Killsounds}` — used respectively by `Menu.ImportFont`, `Menu.ImportImage`, `Menu.Config`/`Menu.ConfigTheme`, and `Menu.Lua` (a small script-loader/manager reading `.lua` files from `Luas/`).

## Notes & caveats

- This documentation was reverse-engineered directly from the extracted source (`ExtractedLib.lua`); the library has no doc comments of its own, so parameter names/behavior above are inferred from each function's default values and body.
- The code contains hard-coded strings referencing third-party branding (e.g. inside `Windows.Watermark`/`Library:Dock` default text) — replace these with your own text via the `Text` parameter before shipping.
- `Menu.Config("Load", ...)` calls `setthreadidentity(7)` before applying each flag — keep that in mind if you're auditing security-sensitive callbacks.
