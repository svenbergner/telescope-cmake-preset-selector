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

--- Shows a Telescope picker with all available custom CMake targets and runs
--- the selected one using the given build preset.
--- @param selectedPreset string The CMake build preset to use
function M.show_cmake_target_picker(selectedPreset)
  local opts = {
    results_title = 'CMake Custom Targets',
    prompt_title = '',
    layout_strategy = 'vertical',
    layout_config = {
      width = 50,
      height = 18,
    },
  }

  pickers
    .new(opts, {
      finder = finders.new_async_job({
        command_generator = function()
          helpers.set_current_index(0)
          return {
            'bash',
            '-c',
            'rg add_custom_target -g "!ExternalLibs/" -I -N | sed "s/add_custom_target(//g" | sed "s/ //g" | sed "s/)//g" | sort | uniq',
          }
        end,
        entry_maker = function(entry)
          if entry == '' or entry == nil then
            return nil
          end
          helpers.set_current_index(helpers.get_current_index() + 1)
          return {
            value = entry,
            display = entry,
            ordinal = entry,
            index = helpers.get_current_index(),
          }
        end,
      }),

      sorter = config.generic_sorter(opts),

      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selectedTarget = actions_state.get_selected_entry().value
          log.debug('Selected target', selectedTarget)
          actions.close(prompt_bufnr)

          local label = selectedPreset .. ' [' .. selectedTarget .. ']'
          cmake_runner.run_cmake_build({
            cmd = 'cmake --build --preset=' .. selectedPreset .. ' --target ' .. selectedTarget,
            label = label,
            preset = label,
          })
        end)
        return true
      end,
    })
    :find()
end

M.show = M.show_cmake_target_picker

return M
