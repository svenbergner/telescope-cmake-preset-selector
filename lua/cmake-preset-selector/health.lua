local M = {}

--- This function is called by `:checkhealth` to report the health of the
--- plugin
M.check = function()
   vim.health.start('CMake Preset Selector Report')
   vim.health.ok('CMake Preset Selector is installed')

   -- cmake binary
   if vim.fn.executable('cmake') == 1 then
      local version = vim.fn.system('cmake --version'):match('cmake version ([%d%.]+)')
      vim.health.ok('cmake found: ' .. (version or 'unknown version'))
   else
      vim.health.error('cmake not found in PATH')
   end

   -- ninja binary (optional)
   if vim.fn.executable('ninja') == 1 then
      vim.health.ok('ninja found')
   else
      vim.health.warn('ninja not found in PATH (only needed for Ninja generator)')
   end

   -- Plugin dependencies
   for _, dep in ipairs({ 'telescope', 'fidget', 'plenary' }) do
      local ok = pcall(require, dep)
      if ok then
         vim.health.ok(dep .. ' is available')
      else
         vim.health.error(dep .. ' is not installed')
      end
   end

   -- CMakePresets.json
   local cwd = vim.fn.getcwd()
   if
      vim.fn.filereadable(cwd .. '/CMakePresets.json') == 1
      or vim.fn.filereadable(cwd .. '/CMakeUserPresets.json') == 1
   then
      vim.health.ok('CMakePresets.json found in ' .. cwd)
   else
      vim.health.warn('No CMakePresets.json found in ' .. cwd)
   end

   -- Current build state
   local helpers = require('helpers')
   local state_info = helpers.get_build_state()
   vim.health.info('Last build state: ' .. state_info.icon .. ' ' .. (state_info.state or 'none'))

   if helpers.get_cmake_build_job_id() ~= nil then
      vim.health.info('A build is currently running')
   end
end

return M
