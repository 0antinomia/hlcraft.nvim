local h = require('tests.helpers')
local scope = 'hlcraft ui context'

local config = require('hlcraft.config')
local context = require('hlcraft.ui.context')
local detail_scene = require('hlcraft.ui.scene.detail')
local engine = require('hlcraft.engine.service')
local hlcraft = require('hlcraft')
local scene = require('hlcraft.ui.scene')

local persist_dir = h.temp_dir('hlcraft-ui-context')
hlcraft.setup({
  persist_dir = persist_dir,
  debounce_ms = 0,
  reapply_events = false,
})

local assert_fails = h.scoped_assert_fails(scope)

vim.api.nvim_set_hl(0, 'HlcraftUiContextNormal', { fg = '#101010' })
engine.set_group('HlcraftUiContextNormal', 'ui-context')
local dynamic_ok, dynamic_err = engine.set_dynamic('HlcraftUiContextNormal', 'fg', {
  version = 1,
  preset = 'pulse',
  duration = 1000,
  loop = 'repeat',
  timeline = {
    { at = 0, color = 'base' },
  },
})
h.assert_true(dynamic_ok, dynamic_err or 'set dynamic failed', scope)

local instance = {
  state = {
    scene = { name = 'field_editor' },
    detail_index = 1,
    field_editor = { field = 'fg' },
    results = {
      { name = 'HlcraftUiContextNormal' },
    },
  },
}

h.assert_true(context.editor_scene_is_active(instance), 'field editor scene was not active', scope)
h.assert_equal(context.current_field(instance), 'fg', 'current field changed', scope)
h.assert_equal(context.current_field_kind(instance), 'color', 'field kind changed', scope)
h.assert_true(context.color_field_is_dynamic(instance), 'dynamic color field was not detected', scope)
h.assert_equal(context.current_color_dynamic(instance).preset, 'pulse', 'dynamic value changed', scope)
assert_fails(function()
  context.editor_scene_is_active(nil)
end, 'UI context accepted missing instance')
assert_fails(function()
  context.current_field({
    state = {},
  })
end, 'UI context accepted missing field editor state')
assert_fails(function()
  context.current_field({
    state = {
      field_editor = { field = false },
    },
  })
end, 'UI context accepted an invalid field')
assert_fails(function()
  context.current_field_kind({
    state = {
      scene = { name = 'field_editor' },
      detail_index = 1,
      field_editor = { field = 'unknown_field' },
    },
  })
end, 'UI context accepted an unsupported field')
assert_fails(function()
  context.current_result({
    state = {
      detail_index = 1,
      field_editor = {},
    },
  })
end, 'UI context accepted missing results')
assert_fails(function()
  context.current_result({
    state = {
      detail_index = 1,
      field_editor = {},
      results = {
        [2] = { name = 'Late' },
      },
    },
  })
end, 'UI context accepted sparse results')

local missing_scene_ok = pcall(scene.current_name, {
  state = {},
})
h.assert_true(not missing_scene_ok, 'scene lookup accepted missing state schema', scope)
assert_fails(function()
  scene.current_name(nil)
end, 'scene lookup accepted missing instance')
local invalid_scene_name_ok = pcall(scene.current_name, {
  state = {
    scene = {},
  },
})
h.assert_true(not invalid_scene_name_ok, 'scene lookup accepted missing scene name', scope)
local empty_scene_name_ok = pcall(scene.current_name, {
  state = {
    scene = {
      name = '',
    },
  },
})
h.assert_true(not empty_scene_name_ok, 'scene lookup accepted an empty scene name', scope)
local invalid_register_name_ok = pcall(scene.register, '', {})
h.assert_true(not invalid_register_name_ok, 'scene register accepted an empty name', scope)
local invalid_register_scene_ok = pcall(scene.register, 'broken', false)
h.assert_true(not invalid_register_scene_ok, 'scene register accepted a non-table scene', scope)
local invalid_register_method_ok = pcall(scene.register, 'broken_method', { handle = 'bad' })
h.assert_true(not invalid_register_method_ok, 'scene register accepted a non-function scene method', scope)
local duplicate_register_ok = pcall(scene.register, 'search', {})
h.assert_true(not duplicate_register_ok, 'scene register accepted a duplicate scene name', scope)
local invalid_scene_opts_ok = pcall(scene.set, instance, 'field_editor', false)
h.assert_true(not invalid_scene_opts_ok, 'scene set accepted non-table options', scope)
local missing_scene_instance_ok = pcall(scene.set, nil, 'field_editor', {})
h.assert_true(not missing_scene_instance_ok, 'scene set accepted missing instance', scope)
local invalid_scene_state_ok = pcall(scene.set, { state = false }, 'field_editor', {})
h.assert_true(not invalid_scene_state_ok, 'scene set accepted invalid instance state', scope)
local scene_name_option_ok = pcall(scene.set, instance, 'field_editor', { name = 'search' })
h.assert_true(not scene_name_option_ok, 'scene set accepted a name option override', scope)
local empty_scene_set_ok = pcall(scene.set, instance, '', {})
h.assert_true(not empty_scene_set_ok, 'scene set accepted an empty scene name', scope)
local failed_scene_instance = {
  state = {
    scene = {
      name = 'search',
    },
  },
}
local failed_detail_set_ok = pcall(scene.set, failed_scene_instance, 'detail', { index = 0 })
h.assert_true(not failed_detail_set_ok, 'scene set accepted an invalid detail entry index', scope)
h.assert_equal(failed_scene_instance.state.scene.name, 'search', 'failed scene entry kept partial scene switch', scope)
assert_fails(function()
  scene.handle(instance, '')
end, 'scene handle accepted an empty action')
assert_fails(function()
  scene.handle({
    state = {
      scene = {
        name = 'missing-scene',
      },
    },
  }, 'activate')
end, 'scene handle accepted an unknown current scene')

local detail_instance = {
  state = {
    detail_index = 1,
  },
}
detail_scene.enter(detail_instance, { index = 2 })
h.assert_equal(detail_instance.state.detail_index, 2, 'detail enter did not set index', scope)
assert_fails(function()
  detail_scene.enter(detail_instance, {})
end, 'detail enter accepted a missing index')
h.assert_equal(detail_instance.state.detail_index, 2, 'failed detail enter changed index', scope)
assert_fails(function()
  detail_scene.enter(nil, {})
end, 'detail enter accepted missing instance')
local invalid_detail_opts_ok = pcall(detail_scene.enter, detail_instance, false)
h.assert_true(not invalid_detail_opts_ok, 'detail enter accepted non-table options', scope)
local unknown_detail_opts_ok = pcall(detail_scene.enter, detail_instance, { cursor = 1 })
h.assert_true(not unknown_detail_opts_ok, 'detail enter accepted unknown options', scope)
local invalid_detail_index_ok = pcall(detail_scene.enter, detail_instance, { index = 0 })
h.assert_true(not invalid_detail_index_ok, 'detail enter accepted invalid index', scope)
assert_fails(function()
  detail_scene.enter(detail_instance, { index = math.huge })
end, 'detail enter accepted infinite index')
assert_fails(function()
  detail_scene.current_result(detail_instance)
end, 'detail current_result accepted missing results')

local refresh_instance = {
  state = {
    detail_index = 1,
    field_editor = { field = 'fg' },
    list_cursor = 1,
    results = {
      { name = 'HlcraftUiContextNormal' },
    },
    scene = { name = 'detail' },
  },
  rerender = function() end,
}
assert_fails(function()
  detail_scene.refresh(refresh_instance, '', true)
end, 'detail refresh accepted empty name')
assert_fails(function()
  detail_scene.refresh(refresh_instance, 'HlcraftUiContextNormal', 'yes')
end, 'detail refresh accepted invalid reopen flag')
assert_fails(function()
  detail_scene.refresh({
    state = refresh_instance.state,
  }, 'HlcraftUiContextNormal', true)
end, 'detail refresh accepted missing rerender callback')
local invalid_refresh_cursor_instance = {
  state = {
    detail_index = 1,
    field_editor = { field = 'fg' },
    list_cursor = 0,
    results = {},
    scene = { name = 'detail' },
  },
  rerender = function() end,
}
assert_fails(function()
  detail_scene.refresh(invalid_refresh_cursor_instance, 'MissingResult', true)
end, 'detail refresh accepted invalid list cursor')
h.assert_equal(
  invalid_refresh_cursor_instance.state.detail_index,
  1,
  'failed detail refresh changed detail index',
  scope
)
h.assert_equal(
  invalid_refresh_cursor_instance.state.field_editor.field,
  'fg',
  'failed detail refresh changed active field',
  scope
)

local refreshed_results_instance = {
  state = {
    detail_index = 1,
    field_editor = { field = 'fg' },
    list_cursor = 1,
    results = {
      { name = 'OldResult' },
      { name = 'FreshResult' },
    },
    scene = { name = 'detail' },
  },
  rerender = function(self)
    self.state.results = {
      { name = 'FreshResult' },
    }
  end,
}
detail_scene.refresh(refreshed_results_instance, 'FreshResult', true)
h.assert_equal(refreshed_results_instance.state.list_cursor, 1, 'detail refresh used stale result cursor', scope)
h.assert_equal(refreshed_results_instance.state.detail_index, 1, 'detail refresh used stale detail index', scope)
h.assert_equal(
  refreshed_results_instance.state.field_editor.field,
  'fg',
  'detail refresh did not preserve active field after refreshed results',
  scope
)
assert_fails(function()
  detail_scene.handle(refresh_instance, '')
end, 'detail handle accepted empty action')

instance.state.field_editor.field = 'blend'
h.assert_equal(context.current_field_kind(instance), 'blend', 'blend field kind changed', scope)
h.assert_true(context.current_color_dynamic(instance) == nil, 'blend field returned color dynamic', scope)

instance.state.scene.name = 'search'
h.assert_true(not context.editor_scene_is_active(instance), 'search scene was treated as editor scene', scope)
h.assert_true(context.current_field_kind(instance) == nil, 'inactive editor returned field kind', scope)

h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui context: OK')
