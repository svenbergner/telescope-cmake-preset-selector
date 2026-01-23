local update_notification = require('helpers').update_notification
local get_build_preset = require('helpers').get_build_preset
local get_configure_preset = require('helpers').get_configure_preset
local get_cmake_build_job_id = require('helpers').get_cmake_build_job_id
local set_cmake_build_job_id = require('helpers').set_cmake_build_job_id
local get_last_build_messages = require('helpers').get_last_build_messages

local function stop_current_cmake_build()
   local cmake_build_job_id = get_cmake_build_job_id()
   if cmake_build_job_id ~= nil then
      vim.fn.jobstop(cmake_build_job_id)
      set_cmake_build_job_id(nil)
      update_notification('CMake build process stopped', 'CMake Build')
   else
      update_notification('No active CMake build process to stop', 'CMake Build', 'warn')
   end
end

local function show_last_build_messages()
   local last_build_messages = get_last_build_messages()
   if #last_build_messages == 0 then
      update_notification('No build messages available', 'CMake Build', 'info')
      return
   end

   -- Create a new buffer
   local buf = vim.api.nvim_create_buf(false, true)

   -- Set buffer options
   vim.bo[buf].bufhidden = 'wipe'
   vim.bo[buf].filetype = 'cmake_build_messages'
   vim.bo[buf].modifiable = false

   -- Set buffer content
   vim.bo[buf].modifiable = true
   vim.api.nvim_buf_set_lines(buf, 0, -1, false, last_build_messages)
   vim.bo[buf].modifiable = false

   -- Calculate window size
   local width = math.floor(vim.o.columns * 0.8)
   local height = math.floor(vim.o.lines * 0.8)
   local row = math.floor((vim.o.lines - height) / 2)
   local col = math.floor((vim.o.columns - width) / 2)

   -- Create floating window
   local win_opts = {
      relative = 'editor',
      width = width,
      height = height,
      row = row,
      col = col,
      style = 'minimal',
      border = 'rounded',
      title = ' CMake Build Messages ',
      title_pos = 'center',
   }

   local win = vim.api.nvim_open_win(buf, true, win_opts)

   -- Set window options
   vim.api.nvim_win_set_option(win, 'wrap', false)
   vim.api.nvim_win_set_option(win, 'cursorline', true)

   -- Set keymaps to close the window with 'q' or '<Esc>'
   local keymaps = {'q', '<Esc>'}
   for _, key in ipairs(keymaps) do
      vim.api.nvim_buf_set_keymap(buf, 'n', key, ':close<CR>', {
         nowait = true,
         noremap = true,
         silent = true
      })
   end

   update_notification('Displaying last build messages (press q to close)', 'CMake Build', 'info')
end

return require('telescope').register_extension({
   exports = {
      show_cmake_configure_presets = require('show_cmake_configure_presets').show_cmake_configure_presets,
      show_cmake_build_presets = require('show_cmake_build_presets').show_cmake_build_presets,
      show_cmake_build_presets_with_target = require('show_cmake_build_presets_with_target').show_cmake_build_presets_with_target,
      show_last_build_messages = show_last_build_messages,
      stop_current_cmake_build = stop_current_cmake_build,
      get_build_preset = get_build_preset,
      get_configure_preset = get_configure_preset,
   },
})

-- Commandline to list cmake build presets
-- cmake --build --preset=$(cmake --list-presets=build | tail -n +3 | fzf | cut -d '\''"'\'' -f2) $@
-- Commandline to list cmake configure presets
-- cmake --preset=$(cmake --list-presets | tail -n +3 | fzf | cut -d '\''"'\'' -f2) $@
-- Commandline to list cmake presets and custom targets
-- cmake_build_preset_with_target='cmake --build --preset=$(cmake --list-presets=build | tail -n +3 | fzf | cut -d '\''"'\'' -f2) --target=$(rg add_custom_target -g !ExternalLibs/ -I -N | sed "s/add_custom_target(//g" | sed "s/ //g" | sed "s/)//g" | sort | uniq | fzf)'

-- vim.cmd('wa | 20split | term time cmake --build --preset=' .. selectedPreset)
-- set makeprg=cd\ build\ &&\ cmake\ -DCMAKE_BUILD_TYPE=debug\ -DCMAKE_EXPORT_COMPILE_COMMANDS=1\ ../view\ &&\ cmake\ --build\ . <bar> :compiler gcc <bar> :make <CR>
