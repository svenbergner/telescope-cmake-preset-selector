local M = {}

M.check = function()
    vim.health.start('CMake Preset Selector Report')
    vim.health.ok('CMake Preset Selector is installed')
end

return M
