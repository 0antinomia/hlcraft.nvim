local tests = {
  'tests/config.lua',
  'tests/init.lua',
  'tests/health.lua',
  'tests/notify.lua',
  'tests/neovim.lua',
  'tests/test_helpers.lua',
  'tests/number.lua',
  'tests/core_timers.lua',
  'tests/tables.lua',
  'tests/color.lua',
  'tests/fields.lua',
  'tests/highlight_entry.lua',
  'tests/highlight_names.lua',
  'tests/core_presets.lua',
  'tests/core_highlights.lua',
  'tests/core_source.lua',
  'tests/core_search.lua',
  'tests/render_util.lua',
  'tests/dynamic_presets.lua',
  'tests/dynamic_model.lua',
  'tests/dynamic_effects.lua',
  'tests/dynamic_runtime.lua',
  'tests/ui_session.lua',
  'tests/ui_dynamic.lua',
  'tests/ui_field_values.lua',
  'tests/ui_handles.lua',
  'tests/ui_state.lua',
  'tests/ui_preview.lua',
  'tests/ui_timers.lua',
  'tests/ui_autocmds.lua',
  'tests/ui_context.lua',
  'tests/ui_search_model.lua',
  'tests/ui_search_scene.lua',
  'tests/ui_json.lua',
  'tests/ui_prompt.lua',
  'tests/ui_input_sequence.lua',
  'tests/ui_input_actions.lua',
  'tests/ui_input_paste_plan.lua',
  'tests/ui_style_editor.lua',
  'tests/ui_editor_rows.lua',
  'tests/ui_editor_layout.lua',
  'tests/ui_hints.lua',
  'tests/ui_help.lua',
  'tests/ui_scene_rows.lua',
  'tests/ui_navigation.lua',
  'tests/ui_unsaved_prompt.lua',
  'tests/ui_workspace_window.lua',
  'tests/ui_workspace_buffer.lua',
  'tests/ui_workspace_lifecycle.lua',
  'tests/ui_keymaps.lua',
  'tests/ui_keymap_commands.lua',
  'tests/ui_field_editor_actions.lua',
  'tests/ui_line_model.lua',
  'tests/ui_line_highlights.lua',
  'tests/ui_placeholders.lua',
  'tests/ui_detail_info.lua',
  'tests/ui_render.lua',
  'tests/persistence_codec.lua',
  'tests/persistence_schema.lua',
  'tests/storage.lua',
  'tests/override_entries.lua',
  'tests/override_values.lua',
  'tests/engine_patch.lua',
  'tests/engine_snapshot.lua',
  'tests/engine_mutations.lua',
  'tests/engine_service.lua',
  'tests/engine_lifecycle.lua',
  'tests/engine_applier.lua',
  'tests/engine_base_specs.lua',
  'tests/engine.lua',
  'tests/overrides.lua',
}

local ignored_files = {
  ['tests/helpers.lua'] = true,
  ['tests/run_all.lua'] = true,
}

local function assert_all_tests_listed()
  local listed = {}
  for _, test_file in ipairs(tests) do
    if listed[test_file] then
      error(('tests/run_all.lua lists test file twice: %s'):format(test_file), 0)
    end
    listed[test_file] = true
  end

  for _, path in ipairs(vim.fn.glob('tests/*.lua', false, true)) do
    local test_file = vim.fn.fnamemodify(path, ':.')
    if not ignored_files[test_file] and not listed[test_file] then
      error(('tests/run_all.lua missing test file: %s'):format(test_file), 0)
    end
  end
end

assert_all_tests_listed()

for _, test_file in ipairs(tests) do
  local ok, err = pcall(dofile, vim.fn.getcwd() .. '/' .. test_file)
  if not ok then
    vim.api.nvim_err_writeln(('hlcraft tests: %s failed: %s'):format(test_file, tostring(err)))
    vim.cmd('cquit')
  end
end

print('hlcraft tests: OK')
