local tests = {
  'tests/config.lua',
  'tests/storage.lua',
  'tests/overrides.lua',
  'tests/ui_workspace.lua',
  'tests/render_workspace.lua',
  'tests/ui_theme.lua',
  'tests/origin_window_switch.lua',
  'tests/smoke.lua',
}

for _, test_file in ipairs(tests) do
  local ok, err = pcall(dofile, vim.fn.getcwd() .. '/' .. test_file)
  if not ok then
    vim.api.nvim_err_writeln(('hlcraft tests: %s failed: %s'):format(test_file, tostring(err)))
    vim.cmd('cquit')
  end
end

print('hlcraft tests: OK')
