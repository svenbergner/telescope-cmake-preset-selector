local M = {}
local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local actions = require('telescope.actions')
local actions_state = require('telescope.actions.state')
local config = require('telescope.config').values

local log = require('plenary.log'):new()
-- log.level = 'debug'

ConfigurePreset = ""
BuildPreset = ""

local current_index = 0
local last_selected_index = 1
local win_handle = nil
local buf_handle = nil

local getPresetFromEntry = function(entry)
        local startOfPreset = entry:find('"', 1) + 1
        if startOfPreset == nil then
                return ""
        end
        local endOfPreset = entry:find('"', startOfPreset + 1) - 1
        return entry:sub(startOfPreset, endOfPreset)
end

local getDescFromEntry = function(entry)
        local entryLen = #entry
        local startOfDesc = entry:find('- ', 1) + 2
        if startOfDesc == nil then
                return ""
        end
        local endOfDesc = entryLen
        return entry:sub(startOfDesc, endOfDesc)
end

local show_cmake_configure_presets = function()
        local opts = {
                results_title = "CMake Configure Presets",
                prompt_title = "",
                default_selection_index = last_selected_index,
                layout_strategy = "vertical",
                layout_config = {
                        width = 80,
                        height = 20,
                },
        }
        pickers.new(opts, {
                finder = finders.new_async_job({
                        command_generator = function()
                                current_index = 0
                                return { "cmake", "--list-presets" }
                        end,
                        entry_maker = function(entry)
                                if (not string.find(entry, '"')) then
                                        return nil
                                end
                                current_index = current_index + 1
                                local preset = getPresetFromEntry(entry)
                                local description = getDescFromEntry(entry)
                                return {
                                        value = preset,
                                        display = description,
                                        ordinal = entry,
                                        index = current_index,
                                }
                        end,
                }),

                sorter = config.generic_sorter(opts),

                attach_mappings = function(prompt_bufnr)
                        actions.select_default:replace(function()
                                local selectedPreset = actions_state.get_selected_entry().value
                                last_selected_index = actions_state.get_selected_entry().index - 2
                                log.debug("attach_mappings", selectedPreset)
                                ConfigurePreset = selectedPreset
                                actions.close(prompt_bufnr)
                                vim.cmd('wa | 20split | term cmake --preset=' .. selectedPreset)
                        end)
                        return true
                end
        }):find()
end

local show_cmake_build_presets = function()
        local opts = {
                results_title = "CMake Build Presets",
                prompt_title = "",
                default_selection_index = last_selected_index,
                layout_strategy = "vertical",
                layout_config = {
                        width = 80,
                        height = 20,
                },
        }
        pickers.new(opts, {
                finder = finders.new_async_job({
                        command_generator = function()
                                current_index = 0
                                return { "cmake", "--list-presets=build" }
                        end,
                        entry_maker = function(entry)
                                if (not string.find(entry, '"')) then
                                        return nil
                                end
                                current_index = current_index + 1
                                local preset = getPresetFromEntry(entry)
                                local description = getDescFromEntry(entry)
                                return {
                                        value = preset,
                                        display = description,
                                        ordinal = entry,
                                        index = current_index,
                                }
                        end,
                }),

                sorter = config.generic_sorter(opts),

                attach_mappings = function(prompt_bufnr)
                        actions.select_default:replace(function()
                                local selectedPreset = actions_state.get_selected_entry().value
                                last_selected_index = actions_state.get_selected_entry().index - 2
                                log.debug("attach_mappings", selectedPreset)
                                BuildPreset = selectedPreset
                                actions.close(prompt_bufnr)

                                local api = vim.api
                                api.nvim_cmd({ cmd = 'wa' }, {}) -- save all buffers
                                vim.fn.setqflist({})
                                local cmd = 'cmake --build --preset=' .. selectedPreset
                                vim.fn.jobstart(cmd, {
                                        stdout_buffered = true,
                                        on_stdout = function(_, data)
                                                if data then
                                                        for _, line in ipairs(data) do
                                                                vim.fn.setqflist({}, 'a', { lines = { line } })
                                                        end
                                                end
                                        end,
                                        on_stderr = function(_, data)
                                                if data then
                                                        for _, line in ipairs(data) do
                                                                vim.fn.setqflist({}, 'a', { lines = { line } })
                                                        end
                                                end
                                        end,
                                        on_exit = function(_, code)
                                                if code == 0 then
                                                        require("noice").notify("Build completed successfully", "info")
                                                        vim.cmd('cclose')
                                                else
                                                        require("noice").notify("Build failed", "error")
                                                        vim.cmd('copen')
                                                        vim.cmd('cnext')
                                                        vim.cmd('wincmd p')
                                                end
                                        end,
                                })
                        end)
                        return true
                end
        }):find()
end

local get_build_preset = function()
        return BuildPreset
end

local get_configure_preset = function()
        return ConfigurePreset
end

return require("telescope").register_extension({
        exports = {
                show_cmake_configure_presets = show_cmake_configure_presets,
                show_cmake_build_presets = show_cmake_build_presets,
                get_build_preset = get_build_preset,
                get_configure_preset = get_configure_preset,
        }
})

-- Commandline to list cmake build presets
-- cmake --build --preset=$(cmake --list-presets=build | tail -n +3 | fzf | cut -d '\''"'\'' -f2) $@
-- Commandline to list cmake configure presets
-- cmake --preset=$(cmake --list-presets | tail -n +3 | fzf | cut -d '\''"'\'' -f2) $@
-- Commandline to list cmake presets and custom targets
-- cmake_build_preset_with_target='cmake --build --preset=$(cmake --list-presets=build | tail -n +3 | fzf | cut -d '\''"'\'' -f2) --target=$(rg add_custom_target -g !ExternalLibs/ -I -N | sed "s/add_custom_target(//g" | sed "s/ //g" | sed "s/)//g" | sort | uniq | fzf)'



-- vim.cmd('wa | 20split | term time cmake --build --preset=' .. selectedPreset)
-- set makeprg=cd\ build\ &&\ cmake\ -DCMAKE_BUILD_TYPE=debug\ -DCMAKE_EXPORT_COMPILE_COMMANDS=1\ ../view\ &&\ cmake\ --build\ . <bar> :compiler gcc <bar> :make <CR>




-- local cmd = 'cmake --build --progress --preset=' .. selectedPreset
-- vim.fn.jobstart(cmd, {
--         stdout_buffered = true,
--         on_stdout = function(_, data)
--                 if data then
--                         require("noice").notify(table.concat(data, "\n"), "info")
--                 end
--         end,
--         on_stderr = function(_, data)
--                 if data then
--                         require("noice").notify(table.concat(data, "\n"), "error")
--                 end
--         end,
--         on_exit = function(_, code)
--                 if code == 0 then
--                         require("noice").notify("Build completed successfully", "info")
--                 else
--                         require("noice").notify("Build failed", "error")
--                         -- Parse the error message to extract file and line number
--                         local error_file, error_line
--                         for _, line in ipairs(code) do
--                                 error_file, error_line = line:match("([^:]+):(%d+):")
--                                 if error_file and error_line then
--                                         break
--                                 end
--                         end
--                         if error_file and error_line then
--                                 vim.api.nvim_command('edit ' .. error_file)
--                                 vim.api.nvim_win_set_cursor(0, { tonumber(error_line), 0 })
--                         end
--                         api.nvim_command('Trouble diagnostics open')
--                 end
--         end,
-- })
