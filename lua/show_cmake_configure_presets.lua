local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local actions = require("telescope.actions")
local actions_state = require("telescope.actions.state")
local config = require("telescope.config").values
local progress = require("fidget.progress")

local scroll_quickfix_to_end_if_open = require("helpers").scroll_quickfix_to_end_if_open
local getPresetFromEntry = require("helpers").getPresetFromEntry
local getDescFromEntry = require("helpers").getDescFromEntry
local get_current_index = require("helpers").get_current_index
local set_current_index = require("helpers").set_current_index
local get_last_selected_index = require("helpers").get_last_selected_index
local set_last_selected_index = require("helpers").set_last_selected_index

local log = require("plenary.log"):new()
-- log.level = 'debug'

local M = {}

function M.show_cmake_configure_presets()
  local opts = {
    results_title = "CMake Configure Presets",
    prompt_title = "",
    default_selection_index = get_last_selected_index(),
    layout_strategy = "vertical",
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
          return { "cmake", "--list-presets" }
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
          set_last_selected_index(actions_state.get_selected_entry().index - 2)
          log.debug("attach_mappings", selectedPreset)
          ConfigurePreset = selectedPreset
          actions.close(prompt_bufnr)

          local api = vim.api
          api.nvim_cmd({ cmd = "wa" }, {}) -- save all buffers
          vim.fn.setqflist({})

          -- Start a new task with fidget
          local handle = progress.handle.create({
            title = "",
            message = "Configuration started for preset: " .. selectedPreset,
            lsp_client = { name = "CMake Configure: " .. selectedPreset },
          })

          -- update_notification("CMake configure started for preset: " .. selectedPreset, "CMake Configure Progress")
          local cmd = "cmake --preset=" .. selectedPreset
          vim.fn.jobstart(cmd, {
            stdout_buffered = false,
            stderr_buffered = true,
            on_stdout = function(_, data)
              if data then
                local progress_message = table.concat(data, "\n")
                -- update_notification(progress_message, "CMake Configure Progress")
                handle.message = progress_message
              end
            end,
            on_stderr = function(_, data)
              if data then
                for _, line in ipairs(data) do
                  vim.fn.setqflist({}, "a", { lines = { line } })
                end
                scroll_quickfix_to_end_if_open()
              end
            end,
            on_exit = function(_, code)
              if code == 0 then
                require("noice").notify("CMake configure successfully completed: " .. selectedPreset, "info")
                vim.cmd("cclose")
              else
                require("noice").notify("CMake configure failed: " .. selectedPreset, "error")
                vim.cmd("copen")
                vim.cmd("cnext")
                vim.cmd("wincmd p")
              end
            end,
          })
        end)
        return true
      end,
    })
    :find()
end

return M
