local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local config = require("telescope.config").values

local getPresetFromEntry = require("helpers").getPresetFromEntry
local getDescFromEntry = require("helpers").getDescFromEntry
local show_cmake_target_picker = require("show_cmake_target_picker").show_cmake_target_picker
local get_current_index = require("helpers").get_current_index
local set_current_index = require("helpers").set_current_index
local get_last_selected_index = require("helpers").get_last_selected_index
local set_last_selected_index = require("helpers").set_last_selected_index

local log = require("plenary.log"):new()
-- log.level = 'debug'

local M = {}

function M.show_cmake_build_presets_with_target()
  local opts = {
    results_title = "CMake Build Presets (with Target)",
    prompt_title = "",
    default_selection_index = get_last_selected_index(),
    layout_strategy = "vertical",
    layout_config = {
      width = 50,
      height = 16,
    },
  }
  pickers
    .new(opts, {
      finder = finders.new_async_job({
        command_generator = function()
          set_current_index(0)
          return { "cmake", "--list-presets=build" }
        end,
        entry_maker = function(entry)
          if not string.find(entry, '"') then
            return nil
          end
          set_current_index(get_current_index() + 1)
          local preset = getPresetFromEntry(entry)
          local description = getDescFromEntry(entry)
          return {
            value = preset,
            display = description,
            ordinal = entry,
            index = get_current_index(),
          }
        end,
      }),

      sorter = config.generic_sorter(opts),

      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selectedPreset = actions_state.get_selected_entry().value
          set_last_selected_index(actions_state.get_selected_entry().index - 2)
          log.debug("Selected preset", selectedPreset)
          BuildPreset = selectedPreset
          actions.close(prompt_bufnr)

          -- After preset selection, show target picker
          show_cmake_target_picker(selectedPreset)
        end)
        return true
      end,
    })
    :find()
end

return M
