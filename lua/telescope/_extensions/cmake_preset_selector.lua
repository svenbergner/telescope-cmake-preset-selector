local pickers = require('telescope.pickers')
local finders = require('telescope.finders')
local actions = require('telescope.actions')
local actions_state = require('telescope.actions.state')
local config = require('telescope.config').values

local log = require('plenary.log'):new()
-- log.level = 'debug'

ConfigurePreset = ""
BuildPreset = ""

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
                layout_strategy = "vertical",
                layout_config = {
                        width = 80,
                        height = 20,
                },
        }
        pickers.new(opts, {
                finder = finders.new_async_job({
                        command_generator = function()
                                return { "cmake", "--list-presets" }
                        end,
                        entry_maker = function(entry)
                                if (not string.find(entry, '"')) then
                                        return nil
                                end
                                local preset = getPresetFromEntry(entry)
                                local description = getDescFromEntry(entry)
                                return {
                                        value = preset,
                                        display = description,
                                        ordinal = entry,
                                }
                        end,
                }),

                sorter = config.generic_sorter(opts),

                attach_mappings = function(prompt_bufnr)
                        actions.select_default:replace(function()
                                local selectedPreset = actions_state.get_selected_entry().value
                                log.debug("attach_mappings", selectedPreset)
                                ConfigurePreset = selectedPreset
                                vim.print("ConfigurePreset: " .. ConfigurePreset)
                                actions.close(prompt_bufnr)
                        end)
                        return true
                end
        }):find()
end

local show_cmake_build_presets = function()
        local opts = {
                results_title = "CMake Build Presets",
                prompt_title = "",
                layout_strategy = "vertical",
                layout_config = {
                        width = 80,
                        height = 20,
                },
        }
        pickers.new(opts, {
                finder = finders.new_async_job({
                        command_generator = function()
                                return { "cmake", "--list-presets=build" }
                        end,
                        entry_maker = function(entry)
                                if (not string.find(entry, '"')) then
                                        return nil
                                end
                                local preset = getPresetFromEntry(entry)
                                local description = getDescFromEntry(entry)
                                return {
                                        value = preset,
                                        display = description,
                                        ordinal = entry,
                                }
                        end,
                }),

                sorter = config.generic_sorter(opts),

                attach_mappings = function(prompt_bufnr)
                        actions.select_default:replace(function()
                                local selectedPreset = actions_state.get_selected_entry().value
                                log.debug("attach_mappings", selectedPreset)
                                BuildPreset = selectedPreset
                                vim.print("BuildPreset: " .. BuildPreset)
                                actions.close(prompt_bufnr)
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
