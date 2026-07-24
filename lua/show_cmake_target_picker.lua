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
            -- Ninja lists custom targets (add_custom_target) as "name: phony"
            -- plus a separate rule line "CMakeFiles/name: CUSTOM_COMMAND" (the
            -- actual custom command). So we first collect all such names from
            -- the CUSTOM_COMMAND rule lines, then classify the plain target
            -- list against that set: custom targets get a "0 " prefix (sorted
            -- to the top), regular targets get a "1 " prefix. Sorting is then
            -- alphabetical within each group. "clean" is always treated as a
            -- custom target.
            '(echo "0 clean"; cmake --build --preset='
              .. selectedPreset
              .. ' -- -t targets all 2>/dev/null'
              .. ' | awk -F": " "{'
              .. 'name=\\$1; rule=\\$2;'
              .. ' if (rule == \\"CUSTOM_COMMAND\\" && name ~ /CMakeFiles\\/[^\\/]+\\$/) {'
              .. ' n=name; sub(/.*CMakeFiles\\//, \\"\\", n);'
              .. ' if (n != \\"edit_cache.util\\" && n != \\"rebuild_cache.util\\") customs[n]=1;'
              .. ' next }'
              .. ' if (name ~ /\\//) next; if (name ~ /\\./) next;'
              .. ' plain[NR]=name }'
              .. ' END { for (i=1;i<=NR;i++) { n=plain[i]; if (n == \\"\\") continue;'
              .. ' if (n in customs) print \\"0 \\" n; else print \\"1 \\" n } }"'
              .. ' | grep -v -e "^[01] cmake_object_order_depends_target_"'
              .. ' -e "^[01] all$" -e "^[01] clean$" -e "^[01] help$"'
              .. ' -e "^[01] edit_cache$" -e "^[01] rebuild_cache$"'
              .. ' -e "_autogen$" -e "_autogen_timestamp_deps$")'
              .. ' | sort -k1,1 -k2,2 -u | sed "s/^[01] //"',
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
