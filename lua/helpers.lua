local configure_preset = ""
local build_preset = ""
local cmake_build_job_id = nil
local current_index = 0
local last_selected_index = 1
local last_build_messages = {} -- Array of {preset, timestamp, messages}
local last_build_state = ''
local build_cancelled_by_user = false
local hourglass_frames = { '', '', '' }
local hourglass_index = 1

local M = {}

-- Returns last build state, which is either 'successful' or 'failed'
---@return string
function M.get_last_build_state()
  return last_build_state
end

-- Sets the last build state to 'successful', 'failed', or 'cancelled'
---@param state string The build state to set ('successful', 'failed', or 'cancelled')
function M.set_last_build_state(state)
  if state == 'successful' or state == 'failed' or state == 'cancelled' then
    last_build_state = state
  else
    error("Invalid build state: " .. tostring(state) .. ". Must be 'successful', 'failed', or 'cancelled'.")
  end
end

-- Returns whether the current build was cancelled by the user
---@return boolean
function M.get_build_cancelled()
  return build_cancelled_by_user
end

-- Sets whether the current build was cancelled by the user
---@param cancelled boolean
function M.set_build_cancelled(cancelled)
  build_cancelled_by_user = cancelled
end

-- Returns all stored build messages
---@return table
function M.get_last_build_messages()
  return last_build_messages
end


-- Returns the next hourglass frame, cycling through all 3 frames on each call
---@return string
function M.get_hourglass()
  local frame = hourglass_frames[hourglass_index]
  hourglass_index = (hourglass_index % #hourglass_frames) + 1
  return frame
end


-- Returns current build state as a table with separate icon, text and state fields.
-- The 'state' field is one of: 'building', 'successful', 'failed', 'idle'.
-- This allows the caller (e.g. a lualine component) to apply colors only to the icon.
---@return { icon: string, text: string, state: string }
function M.get_build_state()
  if cmake_build_job_id ~= nil then
    return {
      icon  = M.get_hourglass(),
      text  = M.get_build_preset(),
      state = 'building',
    }
  else
    local state = M.get_last_build_state()
    local icon
    if state == 'successful' then
      icon = '✓'
    elseif state == 'failed' then
      icon = '✗'
    elseif state == 'cancelled' then
      icon = '⊘'
    else
      icon  = ' '
      state = 'idle'
    end
    return {
      icon  = icon,
      text  = M.get_build_preset(),
      state = state,
    }
  end
end

-- Adds a new build message entry with preset and timestamps
--- @param preset string The build preset used for this build
--- @param messages table An array of messages related to the build
function M.set_last_build_messages(preset, messages)
  local timestamp = os.date("%Y-%m-%d %H:%M:%S")
  table.insert(last_build_messages, {
    preset = preset,
    timestamp = timestamp,
    messages = messages
  })
end

-- Returns only the last (most recent) build message entry
--- @return table|nil The most recent build message entry or nil if none exist
function M.get_last_build_message()
  if #last_build_messages == 0 then
    return nil
  end
  return last_build_messages[#last_build_messages]
end

--- @return string The currently set CMake build preset
function M.get_build_preset()
  return build_preset
end

--- @return string The currently set CMake configure preset
function M.get_configure_preset()
  return configure_preset
end

--- @param preset string The CMake build preset to set
function M.set_build_preset(preset)
  build_preset = preset
end

--- @param preset string The CMake configure preset to set
function M.set_configure_preset(preset)
  configure_preset = preset
end

--- Resets both CMake configure and build presets to empty strings
function M.reset_cmake_presets()
  configure_preset = ""
  build_preset = ""
end

--- @param job_id number|nil The job ID of the currently running CMake build
function M.set_cmake_build_job_id(job_id)
  cmake_build_job_id = job_id
end

--- @return number|nil The job ID of the currently running CMake build, or nil
--- if no build is running
function M.get_cmake_build_job_id()
  return cmake_build_job_id
end

--- @return number The current index used for tracking entries in pickers
function M.get_current_index()
  return current_index
end

--- @param index number The index to set for tracking entries in pickers
function M.set_current_index(index)
  current_index = index
end

--- @return number The last selected index in the picker, used for default
function M.get_last_selected_index()
  return last_selected_index
end

--- @param index number The index to set as the last selected index in the
--- picker
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
