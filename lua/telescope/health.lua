local M = {}

--- This function is called by `:checkhealth` to report the health of the
--- plugin
M.check = function()
    vim.health.start('CMake Preset Selector Report')
    vim.health.ok('CMake Preset Selector is installed')
end

return M
