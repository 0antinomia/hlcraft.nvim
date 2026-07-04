local tests = {
  'tests/config.lua',
  'tests/dynamic_model.lua',
  'tests/dynamic_effects.lua',
  'tests/dynamic_runtime.lua',
  'tests/ui_dynamic.lua',
  'tests/ui_context.lua',
  'tests/ui_keymap_commands.lua',
  'tests/ui_field_editor_actions.lua',
  'tests/ui_render.lua',
  'tests/storage.lua',
  'tests/engine.lua',
  'tests/overrides.lua',
}

for _, test_file in ipairs(tests) do
  local ok, err = pcall(dofile, vim.fn.getcwd() .. '/' .. test_file)
  if not ok then
    vim.api.nvim_err_writeln(('hlcraft tests: %s failed: %s'):format(test_file, tostring(err)))
    vim.cmd('cquit')
  end
end

print('hlcraft tests: OK')
