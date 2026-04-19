local progress = require('fidget.progress')
local helpers = require('helpers')

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

--- Renders a block progress bar, e.g. "████████░░░░"
--- @param pct number Percentage (0-100)
--- @param width number|nil Bar width in characters (default 20)
--- @return string
local function make_progress_bar(pct, width)
  width = width or 20
  local filled = math.floor(pct / 100 * width)
  return string.rep('█', filled) .. string.rep('░', width - filled)
end

--- Truncates a string to the first line and at most max_len characters
--- @param msg string
--- @param max_len number|nil
--- @return string
local function truncate_message(msg, max_len)
  max_len = max_len or math.floor(vim.o.columns * 0.3)
  local first_line = msg:match('([^\n]+)') or msg
  if #first_line > max_len then
    return first_line:sub(1, max_len) .. '…'
  end
  return first_line
end

local M = {}

--- Runs a CMake build command with live progress feedback via fidget,
--- quickfix error collection, and build state tracking.
---
--- @param opts table Configuration table with the following fields:
---   - cmd          string        Full shell command to run (e.g. "cmake --build --preset=foo")
---   - label        string        Human-readable label used in fidget and quickfix titles
---   - preset       string        Preset name used as key for build message history
---   - track_cancel boolean|nil   When true, checks build_cancelled flag on exit (default: false)
function M.run_cmake_build(opts)
  assert(opts.cmd, 'cmake_runner.run_cmake_build: opts.cmd is required')
  assert(opts.label, 'cmake_runner.run_cmake_build: opts.label is required')
  assert(opts.preset, 'cmake_runner.run_cmake_build: opts.preset is required')

  local cmd = opts.cmd
  local label = opts.label
  local preset = opts.preset
  local track_cancel = opts.track_cancel or false

  vim.api.nvim_cmd({ cmd = 'wa' }, {}) -- save all buffers
  vim.fn.setqflist({})
  if track_cancel then
    helpers.set_build_cancelled(false)
  end

  -- Start a fidget progress handle
  local handle = progress.handle.create({
    title = 'Build',
    message = label,
    lsp_client = { name = 'CMake' },
  })

  local starttime = vim.fn.reltime()
  local build_error = false
  local build_messages = {}
  local last_progress_line = ''

  local job_id = vim.fn.jobstart(cmd, {
    stdout_buffered = false,
    stderr_buffered = true,

    on_stdout = function(_, data)
      if not data then return end
      vim.schedule(function()
        for _, line in ipairs(data) do
          if #line > 1 then
            -- Parse cmake/ninja progress: "[N/M]" fraction or "[ X%]" percentage
            local n, m = line:match('%[%s*(%d+)/(%d+)%]')
            if n and m and tonumber(m) > 0 then
              local pct = math.floor(tonumber(n) / tonumber(m) * 100)
              local action = line:match('%[%s*%d+/%d+%]%s*(.*)') or ''
              last_progress_line = make_progress_bar(pct) .. string.format(' [%s/%s]', n, m)
              handle.message = last_progress_line .. '\n' .. truncate_message(action)
            else
              local pct_str = line:match('%[%s*(%d+)%%%]')
              if pct_str then
                local pct = tonumber(pct_str)
                local action = line:match('%[%s*%d+%%%]%s*(.*)') or ''
                last_progress_line = make_progress_bar(pct) .. string.format(' %d%% ', pct)
                handle.message = last_progress_line .. '\n' .. truncate_message(action)
              else
                -- No progress indicator: keep the last progress bar on line 1
                if last_progress_line ~= '' then
                  handle.message = last_progress_line .. '\n' .. truncate_message(line)
                else
                  handle.message = truncate_message(line)
                end
              end
            end

            -- Collect errors into quickfix
            if line:find('error:', 1, true) and not build_error then
              helpers.update_notification(line, 'CMake Build Progress', 'error', 10000)
              vim.fn.setqflist({}, 'r', { title = 'CMake Build Errors: ' .. label })
              build_error = true
            end
            if build_error then
              vim.fn.setqflist({}, 'a', { lines = { line } })
            end

            table.insert(build_messages, line)
          end
        end
        helpers.scroll_quickfix_to_end_if_open()
      end)
    end,

    on_stderr = function(_, data)
      if not data then return end
      vim.schedule(function()
        for _, line in ipairs(data) do
          if #line > 1 then
            vim.fn.setqflist({}, 'a', { lines = { line } })
          end
        end
        helpers.scroll_quickfix_to_end_if_open()
      end)
    end,

    on_exit = function(_, code)
      vim.schedule(function()
        local duration = vim.fn.reltime(starttime, vim.fn.reltime())
        local duration_message = 'Build finished in '
          .. helpers.format_time(duration)
          .. ' with return code '
          .. code
        handle.message = duration_message
        vim.fn.setqflist({}, 'a', { lines = { duration_message } })

        if track_cancel and helpers.get_build_cancelled() then
          helpers.set_build_cancelled(false)
          helpers.set_last_build_state('cancelled')
          handle:cancel()
          helpers.update_notification(
            'Build "' .. label .. '" was cancelled by the user.',
            'CMake Build',
            'warn',
            5000
          )
        elseif code == 0 then
          helpers.set_last_build_state('successful')
          handle:finish()
        else
          helpers.set_last_build_state('failed')
          handle:cancel()
          if #vim.fn.getqflist() > 0 then
            vim.fn.setqflist({}, 'r', { title = 'CMake build ' .. label })
            vim.cmd('copen')
          end
        end

        helpers.set_cmake_build_job_id(nil)
        helpers.set_last_build_messages(preset, build_messages)
      end)
    end,
  })

  helpers.set_cmake_build_job_id(job_id)
end

return M
