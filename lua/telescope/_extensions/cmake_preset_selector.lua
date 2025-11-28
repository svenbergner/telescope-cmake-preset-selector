local update_notification = require("helpers").update_notification
local get_build_preset = require("helpers").get_build_preset
local get_configure_preset = require("helpers").get_configure_preset
local get_cmake_build_job_id = require("helpers").get_cmake_build_job_id
local set_cmake_build_job_id = require("helpers").set_cmake_build_job_id

local function stop_current_cmake_build()
  local cmake_build_job_id = get_cmake_build_job_id()
  if cmake_build_job_id ~= nil then
    vim.fn.jobstop(cmake_build_job_id)
    set_cmake_build_job_id(nil)
    update_notification("CMake build process stopped", "CMake Build")
  else
    update_notification("No active CMake build process to stop", "CMake Build", "warn")
  end
end

return require("telescope").register_extension({
  exports = {
    show_cmake_configure_presets = require('show_cmake_configure_presets').show_cmake_configure_presets,
    show_cmake_build_presets = require('show_cmake_build_presets').show_cmake_build_presets,
    show_cmake_build_presets_with_target = require('show_cmake_build_presets_with_target').show_cmake_build_presets_with_target,
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
