local configure_preset = ""
local build_preset = ""
local cmake_build_job_id = nil
local current_index = 0
local last_selected_index = 1

local M = {}

function M.get_build_preset()
  return build_preset
end

function M.get_configure_preset()
  return configure_preset
end

function M.set_build_preset(preset)
  build_preset = preset
end

function M.set_configure_preset(preset)
  configure_preset = preset
end

function M.reset_cmake_presets()
  configure_preset = ""
  build_preset = ""
end

function M.set_cmake_build_job_id(job_id)
  cmake_build_job_id = job_id
end

function M.get_cmake_build_job_id()
  return cmake_build_job_id
end

function M.get_current_index()
  return current_index
end

function M.set_current_index(index)
  current_index = index
end

function M.get_last_selected_index()
  return last_selected_index
end

function M.set_last_selected_index(index)
  last_selected_index = index
end


-- scroll quickfix window to end if it's open, without giving it focus
function M.scroll_quickfix_to_end_if_open()
  -- Find quickfix window
  local qf_win = nil
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local buf = vim.api.nvim_win_get_buf(win)
    local buf_type = vim.bo[buf].buftype
    if buf_type == "quickfix" then
      qf_win = win
      break
    end
  end

  if qf_win then
    -- Scroll quickfix window to end without changing focus
    vim.api.nvim_win_call(qf_win, function()
      local qf_buf = vim.api.nvim_win_get_buf(qf_win)
      local line_count = vim.api.nvim_buf_line_count(qf_buf)
      vim.api.nvim_win_set_cursor(qf_win, { line_count, 0 })
    end)
  end
end

function M.format_time(duration)
  local total_seconds = vim.fn.reltimefloat(duration)
  total_seconds = total_seconds % 3600
  local minutes = math.floor(total_seconds / 60)
  local seconds = total_seconds % 60
  local milliseconds = (seconds - math.floor(seconds)) * 1000
  seconds = math.floor(seconds)
  return string.format("%02d:%02d.%03d", minutes, seconds, milliseconds)
end

function M.update_notification(message, title, level, timeout)
  level = level or "info"
  timeout = timeout or 3000
  if #message < 1 then
    return
  end
  message = string.gsub(message, "\n.*$", "")
  vim.notify(message, level, {
    id = title,
    title = title,
    position = { row = 1, col = "100%" },
    timeout = timeout, -- Timeout in milliseconds
  })
end

function M.getPresetFromEntry(entry)
  local startPos = entry:find('"', 1)
  if startPos == nil then
    return ""
  end
  local startOfPreset = startPos + 1

  local endPos = entry:find('"', startOfPreset)
  if endPos == nil then
    return ""
  end
  local endOfPreset = endPos - 1

  return entry:sub(startOfPreset, endOfPreset)
end

function M.getDescFromEntry(entry)
  local entryLen = #entry
  local startOfDesc = entry:find("- ", 1)
  if startOfDesc == nil then
    return ""
  end
  startOfDesc = startOfDesc + 2 -- Skip the '- ' part
  local endOfDesc = entryLen
  return entry:sub(startOfDesc, endOfDesc)
end

return M
