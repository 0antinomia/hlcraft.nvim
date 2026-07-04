local tests = {
  'tests/config.lua',
  'tests/highlight_entry.lua',
  'tests/dynamic_model.lua',
  'tests/dynamic_effects.lua',
  'tests/dynamic_runtime.lua',
  'tests/ui_dynamic.lua',
  'tests/ui_state.lua',
  'tests/ui_context.lua',
  'tests/ui_search_model.lua',
  'tests/ui_input_sequence.lua',
  'tests/ui_input_paste_plan.lua',
  'tests/ui_style_editor.lua',
  'tests/ui_scene_rows.lua',
  'tests/ui_unsaved_prompt.lua',
  'tests/ui_keymaps.lua',
  'tests/ui_keymap_commands.lua',
  'tests/ui_field_editor_actions.lua',
  'tests/ui_line_model.lua',
  'tests/ui_line_highlights.lua',
  'tests/ui_render.lua',
  'tests/persistence_codec.lua',
  'tests/storage.lua',
  'tests/engine_patch_values.lua',
  'tests/engine_patch.lua',
  'tests/engine_base_specs.lua',
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
