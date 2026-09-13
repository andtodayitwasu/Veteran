# Veteran UI

> A modern, lightweight Roblox UI library focused on clean layouts, smooth animations, theming, configurations, and extensibility.

**Veteran** is a dark, modular UI framework designed around a simple hierarchy:

```text
Veteran
 └── Window
      └── Tab
           └── Section
                ├── Toggle
                ├── Slider
                ├── Dropdown
                ├── Colorpicker
                ├── Button
                ├── Textbox
                └── Keybind
```

The library includes built-in theme management, configuration persistence, keybind handling, notifications, watermarks, player/environment utilities, and optional Roblox CoreGui redesign functionality.

---

## Features

* Clean dark UI design
* Animated interactions and transitions
* Window system with draggable panels
* Multi-tab layouts
* Left/right section columns
* Toggles
* Sliders
* Dropdowns
* Multi-select dropdowns
* Color pickers
* Buttons
* Textboxes
* Keybinds
* Searchable configurations
* Persistent configurations
* Theme system
* Theme autoloading
* Config import/export
* Notifications
* Confirmation dialogs
* Custom watermarks
* Player/environment viewer
* Player relation system
* Optional CoreGui redesign
* Roblox chat/backpack/player/emote UI integration
* Hotbar support
* Built-in splash screen
* Ready callbacks
* Automatic cleanup through `unload()`

---

## Requirements

Veteran is designed for an environment that supports the functionality used by the library.

The loader/library expects access to functionality such as:

* `getgenv()`
* File functions such as:

  * `readfile`
  * `writefile`
  * `makefolder`
  * `listfiles`
  * `delfile`
* HTTP request functionality when required by the backend
* Standard Roblox services such as:

  * `Players`
  * `TweenService`
  * `UserInputService`
  * `GuiService`
  * `HttpService`
  * `RunService`
  * `Stats`
  * `TextChatService`

The library itself is normally loaded by **`VeteranLoader.lua`** or an equivalent loader. The UI source is not intended to be injected as a completely standalone file.

---

# Installation

Load Veteran through your loader and obtain the global instance:

```lua
local veteran = getgenv().veteran
```

The library automatically exposes itself through:

```lua
getgenv().veteran = veteran
```

and boots the interface during initialization.

If the library has already been loaded, calling the loader again safely unloads the previous instance before creating the new one.

---

# Basic Usage

A minimal Veteran interface can be structured like this:

```lua
local veteran = getgenv().veteran

veteran:window({
    name = "Example",
    size = UDim2.fromOffset(560, 430),
}):tab({
    name = "Main",
}):section({
    name = "General",
})
```

For most projects, controls should be created through a section.

---

# Windows

Create a window with:

```lua
local window = veteran:window({
    name = "Example",
    size = UDim2.fromOffset(560, 430),
    position = UDim2.fromOffset(68, 52),
})
```

### Window properties

| Property     | Type    | Description                      |
| ------------ | ------- | -------------------------------- |
| `name`       | string  | Window title                     |
| `size`       | `UDim2` | Window size                      |
| `position`   | `UDim2` | Initial position                 |
| `tab`        | string  | Associates the window with a tab |
| `frame_name` | string  | Custom frame name                |

Example:

```lua
local window = veteran:window({
    name = "Settings",
    size = UDim2.fromOffset(600, 450),
})
```

Windows are draggable and can be resized programmatically.

```lua
window:resize(UDim2.fromOffset(700, 500))
```

---

# Tabs

Create a tab with:

```lua
local tab = window:tab({
    name = "Main",
})
```

A tab automatically receives left and right columns for sections.

```text
┌──────────────────────────────────────┐
│ Main   Visuals   Settings            │
├──────────────────┬───────────────────┤
│                  │                   │
│   Left Column    │   Right Column    │
│                  │                   │
└──────────────────┴───────────────────┘
```

Tabs can also be opened directly:

```lua
tab:open()
```

---

# Sections

Sections organize controls inside a tab.

```lua
local section = tab:section({
    name = "General",
})
```

By default, sections are placed on the left.

Use the right side with:

```lua
local section = tab:section({
    name = "Settings",
    side = "right",
})
```

Sections are searchable by their name, tab, and associated control metadata.

---

# Controls

## Toggle

```lua
section:toggle({
    name = "Enabled",
    flag = "enabled",
    default = false,

    callback = function(value)
        print("Enabled:", value)
    end,
})
```

### Properties

| Property   | Type     | Description                   |
| ---------- | -------- | ----------------------------- |
| `name`     | string   | Display name                  |
| `flag`     | string   | Configuration identifier      |
| `default`  | boolean  | Initial value                 |
| `callback` | function | Called when the value changes |
| `get`      | function | Custom value getter           |
| `set`      | function | Custom value setter           |
| `color`    | `Color3` | Optional control color        |

---

## Slider

```lua
section:slider({
    name = "Walk Speed",
    flag = "walk_speed",

    min = 1,
    max = 100,
    default = 16,
    interval = 1,

    callback = function(value)
        print("Speed:", value)
    end,
})
```

You can add a suffix:

```lua
section:slider({
    name = "Volume",
    flag = "volume",

    min = 0,
    max = 100,
    default = 50,
    interval = 1,
    suffix = "%",
})
```

Supported aliases include:

```lua
min
minimum

max
maximum

interval
step
decimal
```

---

## Dropdown

```lua
section:dropdown({
    name = "Mode",
    flag = "mode",

    items = {
        "Legit",
        "Blatant",
        "Custom",
    },

    default = "Legit",

    callback = function(value)
        print("Selected:", value)
    end,
})
```

`options` can also be used instead of `items`.

```lua
section:dropdown({
    name = "Mode",
    options = {
        "Legit",
        "Blatant",
        "Custom",
    },
})
```

### Multi-select

```lua
section:dropdown({
    name = "Targets",
    flag = "targets",

    items = {
        "Players",
        "NPCs",
        "Objects",
    },

    multi = true,
    default = {
        "Players",
        "NPCs",
    },

    callback = function(values)
        print(values)
    end,
})
```

---

## Colorpicker

```lua
section:colorpicker({
    name = "Accent",
    flag = "accent",

    default = Color3.fromRGB(132, 120, 148),

    callback = function(color)
        print(color)
    end,
})
```

The picker supports HSV selection and direct RGB input.

RGB values can be entered in the form:

```text
132, 120, 148
```

---

## Button

```lua
section:button({
    name = "Execute",

    callback = function()
        print("Executed!")
    end,
})
```

Buttons are intended for actions that don't require a persistent value.

---

## Textbox

```lua
section:textbox({
    name = "Username",
    flag = "username",

    placeholder = "Enter username...",

    callback = function(value)
        print("Username:", value)
    end,
})
```

You can also control whether text is cleared when the box receives focus:

```lua
section:textbox({
    name = "Search",
    placeholder = "Search...",
    clear_on_focus = true,
})
```

---

## Keybind

```lua
section:keybind({
    name = "Open Menu",
    flag = "menu_key",
    default = Enum.KeyCode.RightShift,
})
```

Keybinds are automatically registered with Veteran's configuration and keybind systems.

Supported key representations include Roblox `Enum.KeyCode` values and supported mouse buttons.

---

# Flags & Options

Controls can be assigned a `flag` so Veteran can manage their values automatically.

```lua
section:toggle({
    name = "Enabled",
    flag = "enabled",
    default = true,
})
```

Read the current value:

```lua
local enabled = veteran:get_option("enabled")
```

Set a value:

```lua
veteran:set_option("enabled", false)
```

This makes flags useful for building larger interfaces without manually maintaining every control's state.

---

# Configurations

Veteran includes a persistent configuration system.

Configurations can store:

* Toggle values
* Slider values
* Dropdown values
* Color values
* Text values
* Keybinds

Export the current configuration:

```lua
local json = veteran:export_config()
```

Import a configuration:

```lua
veteran:import_config(json)
```

You can also access the complete configuration data:

```lua
local config = veteran:dump_config()
```

The exported structure contains:

```lua
{
    options = {},
    binds = {},
}
```

---

# Themes

Veteran has a centralized theme system.

The default accent is:

```lua
Color3.fromRGB(132, 120, 148)
```

Available theme keys include:

```lua
Accent

Window Background
Window Border

Tab Background
Tab Border
Tab Toggle Background

Section Background
Section Border

Text
Disabled Text

Object Background
Object Border

Dropdown Option Background
```

Change a theme value:

```lua
veteran:set_theme(
    "Accent",
    Color3.fromRGB(255, 100, 100)
)
```

All UI elements bound to that theme property update automatically.

---

# Theme Files

Themes can be saved and loaded using Veteran's built-in filesystem support.

Save:

```lua
veteran:write_theme_file("my_theme")
```

Load:

```lua
veteran:load_theme_file("my_theme")
```

Read:

```lua
local theme = veteran:read_theme_file("my_theme")
```

Delete:

```lua
veteran:delete_theme_file("my_theme")
```

List available themes:

```lua
local themes = veteran:list_theme_files()
```

---

# Theme Autoloading

A theme can be marked for automatic loading:

```lua
veteran:set_autoload("my_theme")
```

Disable autoloading:

```lua
veteran:set_autoload()
```

Veteran stores themes under:

```text
veteran/
└── themes/
    ├── current.json
    ├── my_theme.json
    └── autoload.txt
```

---

# Notifications

Display a notification:

```lua
veteran:notification({
    text = "Settings saved",
    duration = 3,
})
```

A string can also be passed directly:

```lua
veteran:notification("Settings saved")
```

The default notification duration is approximately three seconds.

---

# Confirmation Dialogs

Create a confirmation dialog:

```lua
veteran:confirm({
    text = "Are you sure?",
})
```

Confirmation dialogs are displayed above the existing interface and automatically close conflicting UI popups such as dropdowns and color pickers.

---

# Watermark

Veteran includes a configurable watermark.

The watermark can display information such as:

* Veteran name
* Player display name
* Current time
* FPS
* Ping

Example output:

```text
veteran  PlayerName  ·  21:43:12  ·  144 fps  ·  32ms
```

Watermark options can be modified through:

```lua
veteran:set_watermark_opt("enabled", true)
```

The watermark automatically refreshes when its displayed information changes.

---

# Environment

Veteran includes an environment/player panel for inspecting players currently in the server.

The environment system supports:

* Player searching
* Player selection
* Display name
* Username
* User ID
* Team
* Relation status
* Player tagging
* Player viewing
* Player sorting

Relations can be set to:

```text
friendly
enemy
neutral
```

Example:

```lua
veteran:set_relation(player, "friendly")
```

Retrieve a player's relation:

```lua
local relation = veteran:get_relation(player)
```

---

# Player Relations

Relations are persisted locally by Veteran.

Example:

```lua
veteran:set_relation(player, "enemy")
```

Reset to neutral:

```lua
veteran:set_relation(player, "neutral")
```

The UI automatically refreshes the affected player row after changing a relation.

---

# Ready Callback

Use `ready()` when you need to run code after Veteran has finished booting.

```lua
veteran:ready(function(ui)
    print("Veteran is ready!")
end)
```

If Veteran is already booted, the callback is executed asynchronously.

---

# Boot & Unload

Veteran can be manually booted:

```lua
veteran:boot()
```

The boot process initializes the session, GUI, splash screen, top bar, themes, configuration system, and optional CoreGui integrations.

To completely unload Veteran:

```lua
veteran:unload()
```

Unloading removes the interface, disconnects registered connections, restores Roblox UI where applicable, and clears the global Veteran instance.

---

# CoreGui Redesign

Veteran contains an optional CoreGui redesign system.

When enabled for an authorized development environment, Veteran can provide custom versions of:

* Chat
* Backpack
* Player list
* Emotes
* Hotbar

The native Roblox top bar can also be hidden/repositioned as part of the redesign.

CoreGui rewriting is restricted by Veteran's role system and is disabled by default.

```lua
local CoreGui_Redesign = false
```

---

# Layout

The hotbar and top bar have configurable layout values.

Default values:

```lua
{
    hotbar_size = 36,
    hotbar_spacing = 5,

    topbar_autohide = false,
    hide_fullscreen_exit = true,
}
```

Values can be changed through:

```lua
veteran:set_layout("hotbar_size", 40)
veteran:set_layout("hotbar_spacing", 6)

veteran:set_layout("topbar_autohide", true)
veteran:set_layout("hide_fullscreen_exit", false)
```

---

# Internal UI Helpers

Veteran exposes several lower-level helpers for developers extending the library.

Examples include:

```lua
veteran:create()
veteran:make_panel()
veteran:make_draggable()
veteran:make_swatch()
veteran:make_slider()
veteran:make_dropdown()
veteran:make_button()
veteran:make_textbox()
veteran:make_keybind()
```

These are useful when creating custom components that should visually integrate with the Veteran UI.

---

# Example

A more complete interface:

```lua
local veteran = getgenv().veteran

local window = veteran:window({
    name = "Example",
    size = UDim2.fromOffset(600, 450),
})

local main = window:tab({
    name = "Main",
})

local general = main:section({
    name = "General",
})

general:toggle({
    name = "Enabled",
    flag = "enabled",
    default = true,

    callback = function(value)
        print("Enabled:", value)
    end,
})

general:slider({
    name = "Speed",
    flag = "speed",

    min = 1,
    max = 100,
    default = 16,
    interval = 1,

    callback = function(value)
        print("Speed:", value)
    end,
})

general:dropdown({
    name = "Mode",
    flag = "mode",

    items = {
        "Default",
        "Advanced",
        "Custom",
    },

    default = "Default",

    callback = function(value)
        print("Mode:", value)
    end,
})

general:colorpicker({
    name = "Accent",
    flag = "accent",

    default = Color3.fromRGB(132, 120, 148),

    callback = function(color)
        print("Color:", color)
    end,
})

general:textbox({
    name = "Message",
    flag = "message",

    placeholder = "Enter message...",

    callback = function(value)
        print("Message:", value)
    end,
})

general:keybind({
    name = "Menu Key",
    flag = "menu_key",
    default = Enum.KeyCode.RightShift,
})

general:button({
    name = "Notify",

    callback = function()
        veteran:notification("Hello from Veteran!")
    end,
})
```

---

# File Structure

Veteran creates and uses the following local structure:

```text
veteran/
├── themes/
│   ├── *.json
│   └── autoload.txt
│
├── configs/
│   └── ...
│
├── environment.json
└── coregui_rewrite.txt
```

Themes and configuration data are separated so UI appearance can be managed independently from feature configurations.

---

# Design Philosophy

Veteran is built around three main principles:

### Modular

Windows, tabs, sections, and controls are independent pieces that can be composed into larger interfaces.

### Persistent

Themes, options, keybinds, and layout settings can persist between sessions.

### Consistent

Controls use the same theme system, animation behavior, spacing, typography, and interaction patterns throughout the interface.

---

# API Reference

### Core

```lua
veteran:boot()
veteran:unload()
veteran:ready(callback)

veteran:window(props)
veteran:add_tab(name)
veteran:toggle_tab(name)
veteran:select_tab(name)
```

### Controls

```lua
section:toggle(props)
section:slider(props)
section:dropdown(props)
section:colorpicker(props)
section:button(props)
section:textbox(props)
section:keybind(props)
```

### Options

```lua
veteran:get_option(flag)
veteran:set_option(flag, value)
veteran:add_option(def)

veteran:save_config()
veteran:load_config()

veteran:export_config()
veteran:import_config(json)
```

### Themes

```lua
veteran:set_theme(key, color)

veteran:apply_theme_map(map)

veteran:write_theme_file(name)
veteran:read_theme_file(name)
veteran:load_theme_file(name)
veteran:delete_theme_file(name)
veteran:list_theme_files()

veteran:set_autoload(name)
veteran:reset_theme()
```

### UI

```lua
veteran:notification(props)
veteran:confirm(props)

veteran:set_layout(key, value)
veteran:set_watermark_opt(key, value)

veteran:set_relation(player, status)
veteran:get_relation(player)
```

---

# Version

Current version:

```text
1.3.0
```

---

# Notes

Veteran's primary UI source is designed to be loaded by the project's loader rather than executed independently.

Some functionality is environment-specific, particularly filesystem access, HTTP requests, session/license handling, and optional CoreGui rewriting.

For production deployments, keep authentication/backend credentials and other sensitive configuration outside of publicly distributed source files.

---

## License

Choose a license appropriate for your project before publishing this repository.

If this project is proprietary, consider adding:

```text
Copyright © 2026 Veteran

All rights reserved.

Unauthorized redistribution, resale, modification, or
republication of this software is prohibited without permission.
```
