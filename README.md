# cmake-preset-selector

A Neovim plugin to interactively select and run CMake configure/build presets directly from the editor, with live progress feedback via **fidget** and **noice**.

## Features

- **Configure presets** — List and select CMake configure presets (`cmake --list-presets`) and run them with live output.
- **Build presets** — List and select CMake build presets (`cmake --list-presets=build`) and run them with a visual block progress bar.
- **Build preset + target** — Two-step picker: first select a build preset, then a custom CMake target.
- **Custom target picker** — Discover `add_custom_target` entries via `ripgrep` and build them with a selected preset.
- **Progress visualization** — Parses `[N/M]` and `[X%]` patterns from CMake stdout and renders an animated block progress bar (`█░`) via **fidget**.
- **Quickfix integration** — Errors are automatically populated into the quickfix list and opened on build failure.
- **Build state tracking** — Tracks the last build state (`successful`, `failed`, `cancelled`, `dirty`) with icons for status line integration.
- **Snacks.picker support** — Optional alternative picker implementation using [snacks.nvim](https://github.com/folke/snacks.nvim) instead of Telescope.

## Requirements

| Dependency | Purpose |
|---|---|
| [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) | Interactive fuzzy picker UI |
| [j-hui/fidget.nvim](https://github.com/j-hui/fidget.nvim) | Progress notifications |
| [folke/noice.nvim](https://github.com/folke/noice.nvim) | Rich notifications |
| [nvim-lua/plenary.nvim](https://github.com/nvim-lua/plenary.nvim) | Async job utilities |
| [BurntSushi/ripgrep](https://github.com/BurntSushi/ripgrep) | Target discovery (`rg`) |
| CMake ≥ 3.19 | Preset support |

> **Note:** [snacks.nvim](https://github.com/folke/snacks.nvim) is only required if you use the alternative `snacks_pickers` module.

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "sven.bergner/cmake-preset-selector",
  dependencies = {
    "nvim-telescope/telescope.nvim",
    "nvim-lua/plenary.nvim",
    "j-hui/fidget.nvim",
    "folke/noice.nvim",
  },
}
```

## Usage

The plugin exposes four picker functions. Call them from your Neovim config or bind them to keymaps:

```lua
-- Select and run a CMake configure preset
require("show_cmake_configure_presets").show()

-- Select and run a CMake build preset
require("show_cmake_build_presets").show()

-- Select a build preset, then a custom target
require("show_cmake_build_presets_with_target").show()

-- Select a custom target for an already-known preset
require("show_cmake_target_picker").show(preset_name)
```

### Example keymaps

```lua
local cmake = {
  configure  = require("show_cmake_configure_presets"),
  build      = require("show_cmake_build_presets"),
  target     = require("show_cmake_build_presets_with_target"),
}

vim.keymap.set("n", "<leader>cc", cmake.configure.show,  { desc = "CMake: Configure preset" })
vim.keymap.set("n", "<leader>cb", cmake.build.show,      { desc = "CMake: Build preset" })
vim.keymap.set("n", "<leader>ct", cmake.target.show,     { desc = "CMake: Build preset + target" })
```

## Status Line Integration

`helpers.lua` exposes a `get_build_state()` function that returns the current build status for use in status line plugins (e.g. lualine):

```lua
local helpers = require("helpers")

-- Returns { icon = "✔", text = "Build successful", state = "successful" }
local state = helpers.get_build_state()

-- Example lualine component
{
  function()
    local s = helpers.get_build_state()
    return s.icon .. " " .. s.text
  end,
}
```

Possible states:

| State | Icon | Description |
|---|---|---|
| `successful` | ✔ | Last build succeeded |
| `failed` | ✘ | Last build failed |
| `cancelled` | ⊘ | Build was cancelled by the user |
| `dirty` | ● | Presets changed, rebuild recommended |

## License

See [LICENSE](LICENSE).
