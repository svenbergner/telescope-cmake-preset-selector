local update_notification = require('helpers').update_notification
local get_build_preset = require('helpers').get_build_preset
local get_configure_preset = require('helpers').get_configure_preset
local get_cmake_build_job_id = require('helpers').get_cmake_build_job_id
local set_cmake_build_job_id = require('helpers').set_cmake_build_job_id
local set_build_cancelled = require('helpers').set_build_cancelled
local get_last_build_messages = require('helpers').get_last_build_messages
local get_last_build_message = require('helpers').get_last_build_message
local get_build_state = require('helpers').get_build_state

local finders = require('telescope.finders')
local pickers = require('telescope.pickers')
local conf = require('telescope.config').values
local action_state = require('telescope.actions.state')
local actions = require('telescope.actions')

local function stop_current_cmake_build(quiet)
  local cmake_build_job_id = get_cmake_build_job_id()
  if cmake_build_job_id ~= nil then
    set_build_cancelled(true)
    vim.fn.jobstop(cmake_build_job_id)
    set_cmake_build_job_id(nil)
    if not quiet then
      update_notification('CMake build process stopped', 'CMake Build')
    end
  else
    if not quiet then
      update_notification('No active CMake build process to stop', 'CMake Build', 'warn')
    end
  end
end

-- Forward declaration (show_last_build_messages is defined further below)
local show_last_build_messages

-- Parse a build output line into a quickfix item with location info if possible
local function line_to_qf_item(line)
  -- GCC/Clang format: /path/to/file.cpp:42:10: error: message
  local filename, lnum, col, msg = line:match('^(.+):(%d+):(%d+):%s*(.+)$')
  if filename then
    return { filename = filename, lnum = tonumber(lnum), col = tonumber(col), text = msg }
  end
  -- Format without column: /path/to/file.cpp:42: message
  filename, lnum, msg = line:match('^(.+):(%d+):%s*(.+)$')
  if filename then
    return { filename = filename, lnum = tonumber(lnum), text = msg }
  end
  -- Fallback: plain text only
  return { text = line }
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
    footer = ' q / <Esc>: Close  │  a: All Messages  │  <C-q>: Errors → Quickfix  │  <C-a>: All → Quickfix ',
    footer_pos = 'center',
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

  -- Send only error lines to quickfix list, close window and jump to last entry
  vim.api.nvim_buf_set_keymap(buf, 'n', '<C-q>', '', {
    nowait = true,
    noremap = true,
    silent = true,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local qf_items = {}
      for _, line in ipairs(lines) do
        if line:match('[Ee]rror:') or line:match('FAILED') or line:match('fatal error') then
          table.insert(qf_items, line_to_qf_item(line))
        end
      end
      if #qf_items == 0 then
        update_notification('No errors found in build output', 'CMake Build', 'warn')
        return
      end
      vim.fn.setqflist({}, 'r', { items = qf_items })
      vim.api.nvim_win_close(win, true)
      vim.cmd('copen')
      vim.cmd('cfirst')
    end,
  })

  -- Send all lines to quickfix list, close window and jump to last entry
  vim.api.nvim_buf_set_keymap(buf, 'n', '<C-a>', '', {
    nowait = true,
    noremap = true,
    silent = true,
    callback = function()
      local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local qf_items = {}
      for _, line in ipairs(lines) do
        table.insert(qf_items, line_to_qf_item(line))
      end
      vim.fn.setqflist({}, 'r', { items = qf_items })
      vim.api.nvim_win_close(win, true)
      vim.cmd('copen')
      vim.cmd('cfirst')
    end,
  })

  -- Open telescope picker with all available build messages
  vim.api.nvim_buf_set_keymap(buf, 'n', 'a', '', {
    nowait = true,
    noremap = true,
    silent = true,
    callback = function()
      vim.api.nvim_win_close(win, true)
      show_last_build_messages()
    end,
  })

  -- Auto-close this floating window when a snacks picker input becomes active
  local augroup = vim.api.nvim_create_augroup('cmake_floating_win_' .. win, { clear = true })
  vim.api.nvim_create_autocmd('FileType', {
    pattern = 'snacks_picker_input',
    group = augroup,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        vim.api.nvim_win_close(win, true)
      end
    end,
  })

  -- Clean up the augroup when the floating window is closed normally
  vim.api.nvim_create_autocmd('WinClosed', {
    pattern = tostring(win),
    group = augroup,
    once = true,
    callback = function()
      vim.api.nvim_del_augroup_by_id(augroup)
    end,
  })
end

show_last_build_messages = function()
  local all_messages = get_last_build_messages()

  if #all_messages == 0 then
    update_notification('No build messages available', 'CMake Build', 'warn')
    return
  end

  -- Create entries for telescope picker (reversed so newest is first)
  local entries = {}
  for i = #all_messages, 1, -1 do
    local entry = all_messages[i]
    local display_text = string.format('[%s] %s - %d lines', entry.timestamp, entry.preset, #entry.messages)
    table.insert(entries, {
      index = i,
      display = display_text,
      preset = entry.preset,
      timestamp = entry.timestamp,
      messages = entry.messages,
    })
  end

  -- Show telescope picker to select which build messages to view
  pickers
      .new({}, {
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
              local title = string.format(
                ' CMake Build Messages - [%s] %s ',
                selection.value.timestamp,
                selection.value.preset
              )
              show_messages_in_floating_window(selection.value.messages, title)
            end
          end)
          return true
        end,
      })
      :find()
end

local function show_last_build_message()
  local last_message = get_last_build_message()

  if last_message == nil then
    update_notification('No build messages available', 'CMake Build', 'warn')
    return
  end

  -- Show the last build messages in floating window
  local title = string.format(' CMake Build Messages - [%s] %s ', last_message.timestamp, last_message.preset)
  show_messages_in_floating_window(last_message.messages, title)
end

return require('telescope').register_extension({
  exports = {
    show_cmake_configure_presets = require('show_cmake_configure_presets').show_cmake_configure_presets,
    show_cmake_build_presets = require('show_cmake_build_presets').show_cmake_build_presets,
    show_cmake_build_presets_with_target = require('show_cmake_build_presets_with_target')
    .show_cmake_build_presets_with_target,
    show_last_build_messages = show_last_build_messages,
    show_last_build_message = show_last_build_message,
    stop_current_cmake_build = stop_current_cmake_build,
    get_build_preset = get_build_preset,
    get_configure_preset = get_configure_preset,
    get_build_state = get_build_state,
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
