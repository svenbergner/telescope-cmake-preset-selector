local actions = require('telescope.actions')
local actions_state = require('telescope.actions.state')
local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local config = require('telescope.config').values
local progress = require('fidget.progress')

local scroll_quickfix_to_end_if_open = require('helpers').scroll_quickfix_to_end_if_open
local format_time = require('helpers').format_time
local update_notification = require('helpers').update_notification
local getPresetFromEntry = require('helpers').getPresetFromEntry
local getDescFromEntry = require('helpers').getDescFromEntry
local set_cmake_build_job_id = require('helpers').set_cmake_build_job_id
local get_current_index = require('helpers').get_current_index
local set_current_index = require('helpers').set_current_index
local get_last_selected_index = require('helpers').get_last_selected_index
local set_last_selected_index = require('helpers').set_last_selected_index
local set_last_build_messages = require('helpers').set_last_build_messages
local set_build_preset = require('helpers').set_build_preset
local set_last_build_state = require('helpers').set_last_build_state
local get_build_cancelled = require('helpers').get_build_cancelled
local set_build_cancelled = require('helpers').set_build_cancelled

local log = require('plenary.log'):new()
-- log.level = 'debug'

-- Ensure the 'CMake' fidget group uses the @text.note.comment highlight for the 'Build' annotation
do
   local ok, display = pcall(require, 'fidget.progress.display')
   if ok then
      display.options.overrides['CMake'] =
         vim.tbl_extend('force', display.options.overrides['CMake'] or {}, { info_style = '@text.note.comment' })
   end
   local ok2, notification = pcall(require, 'fidget.notification')
   if ok2 and notification.options.configs['CMake'] then
      notification.options.configs['CMake'] =
         vim.tbl_extend('force', notification.options.configs['CMake'], { info_style = '@text.note.comment' })
   end
end

--- Renders a plain block progress bar, e.g. "████████░░░░"
local function make_progress_bar(pct, width)
   width = width or 20
   local filled = math.floor(pct / 100 * width)
   return string.rep('█', filled) .. string.rep('░', width - filled)
end

--- Truncates a string to the first line and at most max_len characters
local function truncate_message(msg, max_len)
   max_len = max_len or math.floor(vim.o.columns * 0.3)
   local first_line = msg:match('([^\n]+)') or msg
   if #first_line > max_len then
      return first_line:sub(1, max_len) .. '…'
   end
   return first_line
end

local M = {}

--- Helper function to show CMake build presets and start build
function M.show_cmake_build_presets()
   local opts = {
      results_title = 'CMake Build Presets',
      prompt_title = '',
      default_selection_index = get_last_selected_index(),
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
               set_current_index(0)
               return { 'cmake', '--list-presets=build' }
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
               set_build_preset(selectedPreset)
               set_last_selected_index(actions_state.get_selected_entry().index - 2)
               log.debug('attach_mappings', selectedPreset)
               BuildPreset = selectedPreset
               actions.close(prompt_bufnr)

               local api = vim.api
               api.nvim_cmd({ cmd = 'wa' }, {}) -- save all buffers
               vim.fn.setqflist({})
               set_build_cancelled(false)

               -- Start a new task with fidget
               local handle = progress.handle.create({
                  title = 'Build',
                  message = selectedPreset,
                  lsp_client = { name = 'CMake' },
               })

               local starttime = vim.fn.reltime()
               local cmd = 'cmake --build --preset=' .. selectedPreset
               local build_error = false
               local build_messages = {}
               local last_progress_line = ''
               local cmake_build_job_id = vim.fn.jobstart(cmd, {
                  stdout_buffered = false,
                  stderr_buffered = true,
                  on_stdout = function(_, data)
                     if data then
                        vim.schedule(function()
                           for _, line in ipairs(data) do
                              if #line > 1 then
                                 -- Parse cmake/ninja progress: "[N/M]" fraction or "[ X%]" percentage
                                 local n, m = line:match('%[%s*(%d+)/(%d+)%]')
                                 if n and m and tonumber(m) > 0 then
                                    local pct = math.floor(tonumber(n) / tonumber(m) * 100)
                                    local action = line:match('%[%s*%d+/%d+%]%s*(.*)')
                                    last_progress_line = make_progress_bar(pct)
                                       .. string.format(' [%s/%s]', n, m)
                                    handle.message = last_progress_line
                                       .. '\n'
                                       .. truncate_message(action or '')
                                 else
                                    local pct = line:match('%[%s*(%d+)%%%]')
                                    if pct then
                                       local action = line:match('%[%s*%d+%%%]%s*(.*)')
                                       last_progress_line = make_progress_bar(tonumber(pct))
                                          .. string.format('%d%% ', tonumber(pct))
                                       handle.message = last_progress_line
                                          .. '\n'
                                          .. truncate_message(action or '')
                                    else
                                       -- No progress indicator: keep the last progress bar on line 1
                                       if last_progress_line ~= '' then
                                          handle.message = last_progress_line
                                             .. '\n'
                                             .. truncate_message(line)
                                       else
                                          handle.message = truncate_message(line)
                                       end
                                    end
                                 end
                                 if line:find('error:', 1, true) and build_error == false then
                                    update_notification(line, 'CMake Build Progress', 'error', 10000)
                                    vim.fn.setqflist({}, 'r', { title = 'CMake Build Errors: ' .. selectedPreset })
                                    build_error = true
                                 end
                                 if build_error then
                                    vim.fn.setqflist({}, 'a', { lines = { line } })
                                 end
                                 table.insert(build_messages, line)
                              end
                           end
                           scroll_quickfix_to_end_if_open()
                        end)
                     end
                  end,
                  on_stderr = function(_, data)
                     if data then
                        vim.schedule(function()
                           for _, line in ipairs(data) do
                              if #line > 1 then
                                 vim.fn.setqflist({}, 'a', { lines = { line } })
                              end
                           end
                           scroll_quickfix_to_end_if_open()
                        end)
                     end
                  end,
                  on_exit = function(_, code)
                     vim.schedule(function()
                        local endtime = vim.fn.reltime()
                        local duration = vim.fn.reltime(starttime, endtime)
                        local duration_message = 'Build finished in '
                           .. format_time(duration)
                           .. ' with return code '
                           .. code
                        handle.message = duration_message
                        vim.fn.setqflist({}, 'a', { lines = { duration_message } })
                        if get_build_cancelled() then
                           -- Build was stopped by the user — do not open qflist
                           set_build_cancelled(false)
                           set_last_build_state('cancelled')
                           handle:cancel()
                           update_notification(
                              'Build "' .. selectedPreset .. '" was cancelled by the user.',
                              'CMake Build',
                              'warn',
                              5000
                           )
                        elseif code == 0 then
                           set_last_build_state('successful')
                           handle:finish()
                        else
                           set_last_build_state('failed')
                           handle:cancel()

                           if #vim.fn.getqflist() > 0 then
                              local qflist_title = 'CMake build ' .. selectedPreset
                              vim.fn.setqflist({}, 'r', { title = qflist_title })
                              vim.cmd('copen')
                           end
                        end
                        set_cmake_build_job_id(nil)
                        set_last_build_messages(selectedPreset, build_messages)
                     end)
                  end,
               })
               set_cmake_build_job_id(cmake_build_job_id)
            end)
            return true
         end,
      })
      :find()
end

return M
