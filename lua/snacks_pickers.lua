local getPresetFromEntry = require("helpers").getPresetFromEntry
local getDescFromEntry = require("helpers").getDescFromEntry

--- Executes a command and uses its output to populate a picker.
---@param picker_opts any
local function pick_cmd_result(picker_opts)
  local function finder(opts, ctx)
    return require("snacks.picker.source.proc").proc({
      opts,
      {
        cmd = picker_opts.cmd,
        args = picker_opts.args,
        transform = picker_opts.transform,
      },
    }, ctx)
  end

  Snacks.picker.pick({
    source = picker_opts.name,
    finder = finder,
    preview = picker_opts.preview,
    title = picker_opts.title,
    layout = picker_opts.layout,
    format = picker_opts.format,
    confirm = picker_opts.confirm,
    filter = picker_opts.filter,
  })
end

-- Snacks custom pickers
-- local Snacks = require("snacks")
-- Custom Pickers
Custom_pickers = {}

--- CMake Build Presets with Target
function Custom_pickers.cmake_build_preset_with_target()
  local preset = ""
  pick_cmd_result({
    cmd = "cmake",
    args = { "--list-presets=build" },
    name = "Custom_pickers.cmake_build_preset_with_target",
    title = "CMake Build Presets with Target",
    format = "text",
    layout = { preset = "vscode" },
    confirm = function(picker, item)
      picker:close()
      preset = item.preset
      vim.print("Selected CMake Build Preset with Target: " .. preset)
      return true
    end,
    transform = function(item)
      local item_preset = getPresetFromEntry(item.text)
      local description = getDescFromEntry(item.text)
      item.preset = item_preset
      item.description = description
      item.text = description
      -- return item
    end,
    -- filter = function(item)
    --   -- vim.print("Filtering item: " .. item.text)
    --   -- return item.text ~= nil and item.text ~= ""
    --   return false
    -- end,
  })

  pick_cmd_result({
    cmd = "cmake",
    args = { "--list-presets=build" },
    name = "Custom_pickers.cmake_build_preset_with_target",
    title = "CMake Build Presets with Target",
    format = "text",
    layout = { preset = "vscode" },
    confirm = function(picker, item)
      picker:close()
      preset = item.preset
      vim.print("Selected CMake Build Preset with Target: " .. preset)
      return true
    end,
    transform = function(item)
      preset = getPresetFromEntry(item.text)
      local description = getDescFromEntry(item.text)
      item.preset = preset
      item.description = description
      item.text = description
      -- return item
    end,
    -- filter = function(item)
    --   -- vim.print("Filtering item: " .. item.text)
    --   -- return item.text ~= nil and item.text ~= ""
    --   return false
    -- end,
  })
end

