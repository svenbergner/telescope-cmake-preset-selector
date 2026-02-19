local update_notification = require('helpers').update_notification
local get_build_preset = require('helpers').get_build_preset
local get_configure_preset = require('helpers').get_configure_preset
local get_cmake_build_job_id = require('helpers').get_cmake_build_job_id
local set_cmake_build_job_id = require('helpers').set_cmake_build_job_id
local get_last_build_messages = require('helpers').get_last_build_messages
local get_last_build_message = require('helpers').get_last_build_message

local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local conf = require('telescope.config').values
local actions = require('telescope.actions')
local action_state = require('telescope.actions.state')

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

-- Helper function to display messages in a floating window
local function show_messages_in_floating_window(messages, title)
   -- Create a new buffer
   local buf = vim.api.nvim_create_buf(false, true)

   -- Set buffer options
   vim.bo[buf].bufhidden = 'wipe'
   vim.bo[buf].filetype = 'cmake_build_messages'

   -- Set buffer content
   vim.api.nvim_buf_set_lines(buf, 0, -1, false, messages)
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
      title = title,
      title_pos = 'center',
   }

   local win = vim.api.nvim_open_win(buf, true, win_opts)

   -- Set window options
   vim.api.nvim_set_option_value('wrap', false, { win = win })
   vim.api.nvim_set_option_value('cursorline', true, { win = win })

   -- Set keymaps to close the window with 'q' or '<Esc>'
   local keymaps = { 'q', '<Esc>' }
   for _, key in ipairs(keymaps) do
      vim.api.nvim_buf_set_keymap(buf, 'n', key, ':close<CR>', {
         nowait = true,
         noremap = true,
         silent = true,
      })
   end
end

local function show_last_build_messages()
   local all_messages = get_last_build_messages()

   if #all_messages == 0 then
      update_notification('No build messages available', 'CMake Build', 'warn')
      return
   end

   -- Create entries for telescope picker (reversed so newest is first)
   local entries = {}
   for i = #all_messages, 1, -1 do
      local entry = all_messages[i]
      local display_text = string.format('[%s] %s - %d lines',
         entry.timestamp,
         entry.preset,
         #entry.messages)
      table.insert(entries, {
         index = i,
         display = display_text,
         preset = entry.preset,
         timestamp = entry.timestamp,
         messages = entry.messages
      })
   end

   -- Show telescope picker to select which build messages to view
   pickers.new({}, {
      prompt_title = 'Select Build Messages to View',
      finder = finders.new_table({
         results = entries,
         entry_maker = function(entry)
            return {
               value = entry,
               display = entry.display,
               ordinal = entry.display,
            }
         end,
      }),
      sorter = conf.generic_sorter({}),
      previewer = require('telescope.previewers').new_buffer_previewer({
         title = 'Build Messages Preview',
         define_preview = function(self, entry)
            -- Set preview buffer content to the messages
            vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, false, entry.value.messages)
            -- Set syntax highlighting for cmake_build_messages
            vim.bo[self.state.bufnr].filetype = 'cmake_build_messages'
         end,
      }),
      layout_config = {
         height = 0.8,
         width = 0.8,
         preview_width = 0.7,
      },
      attach_mappings = function(prompt_bufnr)
         actions.select_default:replace(function()
            actions.close(prompt_bufnr)
            local selection = action_state.get_selected_entry()
            if selection then
               -- Show messages in floating window
               local title = string.format(' CMake Build Messages - [%s] %s ',
                  selection.value.timestamp,
                  selection.value.preset)
               show_messages_in_floating_window(selection.value.messages, title)
            end
         end)
         return true
      end,
   }):find()
end

local function show_last_build_message()
   local last_message = get_last_build_message()

   if last_message == nil then
      update_notification('No build messages available', 'CMake Build', 'warn')
      return
   end

   -- Show the last build messages in floating window
   local title = string.format(' CMake Build Messages - [%s] %s ',
      last_message.timestamp,
      last_message.preset)
   show_messages_in_floating_window(last_message.messages, title)
end

return require('telescope').register_extension({
   exports = {
      show_cmake_configure_presets = require('show_cmake_configure_presets').show_cmake_configure_presets,
      show_cmake_build_presets = require('show_cmake_build_presets').show_cmake_build_presets,
      show_cmake_build_presets_with_target = require('show_cmake_build_presets_with_target').show_cmake_build_presets_with_target,
      show_last_build_messages = show_last_build_messages,
      show_last_build_message = show_last_build_message,
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
