local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local config = require("telescope.config").values
local progress = require("fidget.progress")

local scroll_quickfix_to_end_if_open = require("helpers").scroll_quickfix_to_end_if_open
local format_time = require("helpers").format_time
local update_notification = require("helpers").update_notification
local set_cmake_build_job_id = require("helpers").set_cmake_build_job_id

local log = require("plenary.log"):new()
-- log.level = 'debug'

local current_index = 0

local M = {}

-- Helper function to show target picker and start build
function M.show_cmake_target_picker(selectedPreset)
  local opts = {
    results_title = "CMake Custom Targets",
    prompt_title = "",
    layout_strategy = "vertical",
    layout_config = {
      width = 50,
      height = 18,
    },
  }

  pickers
    .new(opts, {
      finder = finders.new_async_job({
        command_generator = function()
          current_index = 0
          return {
            "bash",
            "-c",
            'rg add_custom_target -g "!ExternalLibs/" -I -N | sed "s/add_custom_target(//g" | sed "s/ //g" | sed "s/)//g" | sort | uniq'
          }
        end,
        entry_maker = function(entry)
          if entry == "" or entry == nil then
            return nil
          end
          current_index = current_index + 1
          return {
            value = entry,
            display = entry,
            ordinal = entry,
            index = current_index,
          }
        end,
      }),

      sorter = config.generic_sorter(opts),

      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          local selectedTarget = actions_state.get_selected_entry().value
          log.debug("Selected target", selectedTarget)
          actions.close(prompt_bufnr)

          local api = vim.api
          api.nvim_cmd({ cmd = "wa" }, {}) -- save all buffers
          vim.fn.setqflist({})

          -- Start a new task with fidget
          local handle = progress.handle.create({
            title = "",
            message = "Build started for preset: " .. selectedPreset .. " with target: " .. selectedTarget,
            lsp_client = { name = "CMake Build: " .. selectedPreset .. " [" .. selectedTarget .. "]" },
          })

          local starttime = vim.fn.reltime()
          local cmd = "cmake --build --preset=" .. selectedPreset .. " --target " .. selectedTarget
          local build_error = false
          local build_error_messages = {}
          local cmake_build_job_id = vim.fn.jobstart(cmd, {
            stdout_buffered = false,
            stderr_buffered = true,
            on_stdout = function(_, data)
              if data then
                local progress_message = table.concat(data, "\n")
                handle.message = progress_message
                for _, line in ipairs(data) do
                  if #line > 1 then
                    if line:find("error:", 1, true) and build_error == false then
                      update_notification(line, "CMake Build Progress", "error", 10000)
                      vim.fn.setqflist({}, "r", { title = "CMake Build Errors: " .. selectedPreset .. " [" .. selectedTarget .. "]" })
                      vim.fn.setqflist({}, "a", { lines = build_error_messages })
                      build_error = true
                    end
                    if build_error then
                      vim.fn.setqflist({}, "a", { lines = { line } })
                    else
                      table.insert(build_error_messages, line)
                    end
                  end
                end
                scroll_quickfix_to_end_if_open()
              end
            end,
            on_stderr = function(_, data)
              if data then
                for _, line in ipairs(data) do
                  if #line > 1 then
                    vim.fn.setqflist({}, "a", { lines = { line } })
                  end
                end
                scroll_quickfix_to_end_if_open()
              end
            end,
            on_exit = function(_, code)
              local endtime = vim.fn.reltime()
              local duration = vim.fn.reltime(starttime, endtime)
              local duration_message = "Build finished in " .. format_time(duration) .. " with return code " .. code
              handle.message = duration_message
              vim.fn.setqflist({}, "a", { lines = { duration_message } })
              if code == 0 then
                handle:finish()
              else
                handle:cancel()

                if #vim.fn.getqflist() > 0 then
                  local qflist_title = "CMake build " .. selectedPreset .. " [" .. selectedTarget .. "]"
                  vim.fn.setqflist({}, "r", { title = qflist_title })
                  vim.cmd("copen")
                end
              end
              set_cmake_build_job_id(nil)
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

