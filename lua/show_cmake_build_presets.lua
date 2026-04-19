local actions = require('telescope.actions')
local actions_state = require('telescope.actions.state')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local config = require('telescope.config').values

local helpers = require('helpers')
local cmake_runner = require('cmake_runner')

local log = require('plenary.log'):new()
-- log.level = 'debug'

local M = {}

--- Shows a Telescope picker with all available CMake build presets.
--- On selection the build is started via cmake_runner.
function M.show_cmake_build_presets()
  local opts = {
    results_title = 'CMake Build Presets',
    prompt_title = '',
    default_selection_index = helpers.get_last_selected_index(),
    layout_strategy = 'vertical',
    layout_config = {
      width = 50,
      height = 16,
    },
  }
  pickers
    .new(opts, {
      finder = finders.new_async_job({
        command_generator = function()
          helpers.set_current_index(0)
          return { 'cmake', '--list-presets=build' }
        end,
        entry_maker = function(entry)
          if not string.find(entry, '"') then
            return nil
          end
          helpers.set_current_index(helpers.get_current_index() + 1)
          local preset = helpers.getPresetFromEntry(entry)
          local description = helpers.getDescFromEntry(entry)
          return {
            value = preset,
            display = description,
            ordinal = entry,
            index = helpers.get_current_index(),
          }
        end,
      }),

      sorter = config.generic_sorter(opts),

      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local entry = actions_state.get_selected_entry()
          local selectedPreset = entry.value
          helpers.set_build_preset(selectedPreset)
          helpers.set_last_selected_index(entry.index - 2)
          log.debug('Selected preset', selectedPreset)
          actions.close(prompt_bufnr)

          cmake_runner.run_cmake_build({
            cmd = 'cmake --build --preset=' .. selectedPreset,
            label = selectedPreset,
            preset = selectedPreset,
            track_cancel = true,
          })
        end)
        return true
      end,
    })
    :find()
end

M.show = M.show_cmake_build_presets

return M
