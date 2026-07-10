local h = require('tests.helpers')
local scope = 'hlcraft ui context'

local config = require('hlcraft.config')
local context = require('hlcraft.ui.context')
local detail_scene = require('hlcraft.ui.scene.detail')
local dynamic_runtime = require('hlcraft.dynamic.runtime')
local engine = require('hlcraft.engine.service')
local hlcraft = require('hlcraft')
local scene = require('hlcraft.ui.scene')

local persist_dir = h.temp_dir('hlcraft-ui-context')
hlcraft.setup({
  persistence = {
    dir = persist_dir,
    reapply_events = {
      enabled = false,
    },
  },
  search = {
    debounce_ms = 0,
  },
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
scene.register('mutating_failure', {
  enter = function(target)
    target.state.field_editor.field = 'bg'
    target.state.results = {
      { name = 'Mutated' },
    }
    error('scene enter failed')
  end,
})
local mutating_scene_instance = {
  state = {
    field_editor = { field = 'fg' },
    results = {
      { name = 'Original' },
    },
    scene = {
      name = 'search',
    },
  },
}
local mutating_scene_ok = pcall(scene.set, mutating_scene_instance, 'mutating_failure')
h.assert_true(not mutating_scene_ok, 'scene set accepted failed mutating scene entry', scope)
h.assert_equal(mutating_scene_instance.state.scene.name, 'search', 'failed mutating scene changed scene', scope)
h.assert_equal(mutating_scene_instance.state.field_editor.field, 'fg', 'failed mutating scene changed field', scope)
h.assert_true(
  vim.deep_equal(mutating_scene_instance.state.results, {
    { name = 'Original' },
  }),
  'failed mutating scene changed results',
  scope
)
scene.register('mutating_render_failure', {
  render = function(target)
    target.state.list_cursor = 2
    target.state.results = {
      { name = 'Mutated' },
    }
    error('scene render failed')
  end,
})
local mutating_render_instance = {
  state = {
    list_cursor = 1,
    results = {
      { name = 'Original' },
    },
    scene = {
      name = 'mutating_render_failure',
    },
  },
}
local mutating_render_ok = pcall(scene.render, mutating_render_instance)
h.assert_true(not mutating_render_ok, 'scene render accepted failed model update', scope)
h.assert_equal(mutating_render_instance.state.list_cursor, 1, 'failed scene render changed list cursor', scope)
h.assert_true(
  vim.deep_equal(mutating_render_instance.state.results, {
    { name = 'Original' },
  }),
  'failed scene render changed results',
  scope
)
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
  detail_scene.refresh({
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
  }, 'Bad Name', true)
end, 'detail refresh accepted whitespace in name')
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

local failed_refresh_instance = {
  state = {
    detail_index = 2,
    field_editor = { field = 'bg' },
    list_cursor = 2,
    results = {
      { name = 'OldResult' },
      { name = 'MissingResult' },
    },
    scene = { name = 'detail' },
  },
  rerender = function(self)
    self.state.results = {}
    error('render failed')
  end,
}
local failed_refresh_ok = pcall(detail_scene.refresh, failed_refresh_instance, 'MissingResult', true)
h.assert_true(not failed_refresh_ok, 'detail refresh accepted failed render', scope)
h.assert_equal(failed_refresh_instance.state.detail_index, 2, 'failed detail refresh changed detail index', scope)
h.assert_equal(failed_refresh_instance.state.field_editor.field, 'bg', 'failed detail refresh changed field', scope)
h.assert_equal(failed_refresh_instance.state.list_cursor, 2, 'failed detail refresh changed list cursor', scope)
h.assert_true(
  vim.deep_equal(failed_refresh_instance.state.results, {
    { name = 'OldResult' },
    { name = 'MissingResult' },
  }),
  'failed detail refresh changed results',
  scope
)
h.assert_equal(failed_refresh_instance.state.scene.name, 'detail', 'failed detail refresh changed scene', scope)

h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'old detail' })
  local render_count = 0
  local failed_reopen_render_instance = {
    state = {
      buf = buf,
      detail_index = 2,
      field_editor = { field = 'bg' },
      list_cursor = 2,
      results = {
        { name = 'OldResult' },
        { name = 'FreshResult' },
      },
      scene = { name = 'detail' },
    },
    rerender = function(self)
      render_count = render_count + 1
      if render_count == 1 then
        self.state.results = {
          { name = 'FreshResult' },
        }
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'fresh search' })
        return
      end
      if render_count == 2 then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'broken detail' })
        error('detail render failed')
      end
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'restored detail' })
    end,
  }
  local failed_reopen_render_ok = pcall(detail_scene.refresh, failed_reopen_render_instance, 'FreshResult', true)
  h.assert_true(not failed_reopen_render_ok, 'detail refresh accepted failed reopen render', scope)
  h.assert_equal(render_count, 3, 'failed detail refresh did not rerender restored state', scope)
  h.assert_equal(
    table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'),
    'restored detail',
    'failed detail refresh left partially rendered content',
    scope
  )
  h.assert_equal(
    failed_reopen_render_instance.state.detail_index,
    2,
    'reopen-render-failed detail refresh changed detail index',
    scope
  )
  h.assert_equal(
    failed_reopen_render_instance.state.field_editor.field,
    'bg',
    'reopen-render-failed detail refresh changed field',
    scope
  )
end, { current = true })

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

h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'fg row' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local failed_activate_instance = {
    state = {
      buf = buf,
      detail_index = 1,
      field_editor = {},
      geometry = {
        detail_menu = {
          fg = {
            line = 1,
            key = 'fg',
            kind = 'color',
          },
        },
      },
      last_workspace_win = vim.api.nvim_get_current_win(),
      results = {
        { name = 'HlcraftUiContextNormal' },
      },
      scene = { name = 'detail' },
    },
    rerender = function()
      error('render failed')
    end,
  }
  local failed_activate_ok = pcall(detail_scene.activate, failed_activate_instance)
  h.assert_true(not failed_activate_ok, 'detail activate accepted failed field editor render', scope)
  h.assert_true(failed_activate_instance.state.field_editor.field == nil, 'failed detail activate changed field', scope)
  h.assert_equal(failed_activate_instance.state.scene.name, 'detail', 'failed detail activate changed scene', scope)
end, { current = true })

h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'detail row' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local partial_activate_renders = 0
  local partial_activate_instance = {
    state = {
      buf = buf,
      detail_index = 1,
      field_editor = {},
      geometry = {
        detail_menu = {
          fg = {
            line = 1,
            key = 'fg',
            kind = 'color',
          },
        },
      },
      last_workspace_win = vim.api.nvim_get_current_win(),
      results = {
        { name = 'HlcraftUiContextNormal' },
      },
      scene = { name = 'detail' },
    },
    rerender = function(self)
      partial_activate_renders = partial_activate_renders + 1
      if self.state.scene.name == 'field_editor' then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'broken editor' })
        error('render failed')
      end
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'restored detail' })
    end,
  }
  local partial_activate_ok = pcall(detail_scene.activate, partial_activate_instance)
  h.assert_true(not partial_activate_ok, 'detail activate accepted partial field editor render', scope)
  h.assert_equal(partial_activate_renders, 2, 'partial-failed detail activate did not rerender restored state', scope)
  h.assert_equal(
    table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'),
    'restored detail',
    'partial-failed detail activate kept field editor content',
    scope
  )
  h.assert_true(
    partial_activate_instance.state.field_editor.field == nil,
    'partial-failed detail activate changed field',
    scope
  )
  h.assert_equal(
    partial_activate_instance.state.scene.name,
    'detail',
    'partial-failed detail activate changed scene',
    scope
  )
end, { current = true })

h.with_temp_buf(function(buf)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'detail row' })
  vim.api.nvim_win_set_cursor(0, { 1, 0 })
  local restore_render_failure_instance = {
    state = {
      buf = buf,
      detail_index = 1,
      field_editor = {},
      geometry = {
        detail_menu = {
          fg = {
            line = 1,
            key = 'fg',
            kind = 'color',
          },
        },
      },
      last_workspace_win = vim.api.nvim_get_current_win(),
      results = {
        { name = 'HlcraftUiContextNormal' },
      },
      scene = { name = 'detail' },
    },
    rerender = function(self)
      if self.state.scene.name == 'field_editor' then
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'broken editor' })
        error('render failed')
      end
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'restore failed' })
      error('restore render failed')
    end,
  }
  local restore_render_failure_ok, restore_render_failure_err =
    pcall(detail_scene.activate, restore_render_failure_instance)
  h.assert_true(not restore_render_failure_ok, 'detail activate accepted failed restore render', scope)
  h.assert_true(
    tostring(restore_render_failure_err):find('restore render failed', 1, true) ~= nil,
    'detail activate restore render failure did not report restore error',
    scope
  )
  h.assert_true(
    restore_render_failure_instance.state.field_editor.field == nil,
    'restore-render-failed detail activate changed field',
    scope
  )
  h.assert_equal(
    restore_render_failure_instance.state.scene.name,
    'detail',
    'restore-render-failed detail activate changed scene',
    scope
  )
end, { current = true })

local failed_force_close_instance = {
  state = {
    detail_index = 1,
    field_editor = { field = 'fg' },
    list_cursor = 1,
    results = {
      { name = 'HlcraftUiContextNormal' },
    },
    scene = { name = 'detail' },
    unsaved_prompt = {},
  },
  rerender = function()
    error('render failed')
  end,
}
local failed_force_close_ok = pcall(detail_scene.force_close, failed_force_close_instance)
h.assert_true(not failed_force_close_ok, 'detail force_close accepted failed render', scope)
h.assert_equal(
  failed_force_close_instance.state.detail_index,
  1,
  'failed detail force_close changed detail index',
  scope
)
h.assert_equal(
  failed_force_close_instance.state.field_editor.field,
  'fg',
  'failed detail force_close changed field',
  scope
)
h.assert_equal(failed_force_close_instance.state.scene.name, 'detail', 'failed detail force_close changed scene', scope)

h.with_temp_buf(function(prompt_buf)
  local prompt_win = vim.api.nvim_open_win(prompt_buf, false, {
    relative = 'editor',
    width = 12,
    height = 1,
    row = 1,
    col = 1,
  })
  local prompt_render_failure_instance = {
    state = {
      detail_index = 1,
      field_editor = { field = 'fg' },
      list_cursor = 1,
      results = {
        { name = 'HlcraftUiContextNormal' },
      },
      scene = { name = 'detail' },
      unsaved_prompt = {
        buf = prompt_buf,
        win = prompt_win,
      },
    },
    rerender = function()
      error('render failed')
    end,
  }
  local prompt_render_failure_ok = pcall(detail_scene.force_close, prompt_render_failure_instance)
  h.assert_true(not prompt_render_failure_ok, 'detail force_close accepted failed render after prompt close', scope)
  h.assert_equal(
    prompt_render_failure_instance.state.unsaved_prompt.win,
    prompt_win,
    'render-failed detail force_close dropped prompt window',
    scope
  )
  h.assert_true(vim.api.nvim_win_is_valid(prompt_win), 'render-failed detail force_close closed prompt window', scope)
  vim.api.nvim_win_close(prompt_win, true)
end)

h.with_temp_buf(function(workspace_buf)
  vim.api.nvim_buf_set_lines(workspace_buf, 0, -1, false, { 'result row' })
  local prompt_buf = vim.api.nvim_create_buf(false, true)
  local prompt_win = vim.api.nvim_open_win(prompt_buf, false, {
    relative = 'editor',
    width = 12,
    height = 1,
    row = 1,
    col = 1,
  })
  local cursor_failure_instance = {
    state = {
      buf = workspace_buf,
      detail_index = 1,
      field_editor = { field = 'fg' },
      geometry = {
        result_lines = {
          [1] = 1,
        },
      },
      last_workspace_win = vim.api.nvim_get_current_win(),
      list_cursor = 1,
      results = {
        { name = 'HlcraftUiContextNormal' },
      },
      scene = { name = 'detail' },
      unsaved_prompt = {
        buf = prompt_buf,
        win = prompt_win,
      },
    },
    rerender = function(self)
      self.state.geometry = {
        result_lines = {
          [1] = 1,
        },
      }
    end,
  }
  local original_win_set_cursor = vim.api.nvim_win_set_cursor
  vim.api.nvim_win_set_cursor = function()
    error('cursor failed')
  end
  local cursor_failure_ok = pcall(detail_scene.force_close, cursor_failure_instance)
  vim.api.nvim_win_set_cursor = original_win_set_cursor
  h.assert_true(not cursor_failure_ok, 'detail force_close accepted failed cursor restore', scope)
  h.assert_equal(
    cursor_failure_instance.state.detail_index,
    1,
    'cursor-failed detail force_close changed detail index',
    scope
  )
  h.assert_equal(
    cursor_failure_instance.state.unsaved_prompt.win,
    prompt_win,
    'cursor-failed detail force_close dropped prompt window',
    scope
  )
  h.assert_true(vim.api.nvim_win_is_valid(prompt_win), 'cursor-failed detail force_close closed prompt window', scope)
  vim.api.nvim_win_close(prompt_win, true)
end, { current = true })

h.with_temp_buf(function(prompt_buf)
  local prompt_win = vim.api.nvim_open_win(prompt_buf, false, {
    relative = 'editor',
    width = 12,
    height = 1,
    row = 1,
    col = 1,
  })
  local close_failure_instance = {
    state = {
      detail_index = 1,
      field_editor = { field = 'fg' },
      list_cursor = 1,
      results = {
        { name = 'HlcraftUiContextNormal' },
      },
      scene = { name = 'detail' },
      unsaved_prompt = {
        buf = prompt_buf,
        win = prompt_win,
      },
    },
    rerender = function() end,
  }
  local original_win_close = vim.api.nvim_win_close
  local original_buf_delete = vim.api.nvim_buf_delete
  vim.api.nvim_win_close = function()
    error('prompt close failed')
  end
  vim.api.nvim_buf_delete = function()
    error('prompt delete failed')
  end
  local close_failure_ok = pcall(detail_scene.force_close, close_failure_instance)
  vim.api.nvim_win_close = original_win_close
  vim.api.nvim_buf_delete = original_buf_delete
  h.assert_true(not close_failure_ok, 'detail force_close ignored failed prompt close', scope)
  h.assert_equal(
    close_failure_instance.state.detail_index,
    1,
    'prompt-close-failed detail force_close changed detail index',
    scope
  )
  h.assert_equal(
    close_failure_instance.state.field_editor.field,
    'fg',
    'prompt-close-failed detail force_close changed field',
    scope
  )
  h.assert_equal(
    close_failure_instance.state.unsaved_prompt.win,
    prompt_win,
    'prompt-close-failed detail force_close dropped prompt window',
    scope
  )
  h.assert_true(
    vim.api.nvim_win_is_valid(prompt_win),
    'prompt-close-failed detail force_close invalidated test window',
    scope
  )
  vim.api.nvim_win_close(prompt_win, true)
end)

instance.state.field_editor.field = 'blend'
h.assert_equal(context.current_field_kind(instance), 'blend', 'blend field kind changed', scope)
h.assert_true(context.current_color_dynamic(instance) == nil, 'blend field returned color dynamic', scope)

instance.state.scene.name = 'search'
h.assert_true(not context.editor_scene_is_active(instance), 'search scene was treated as editor scene', scope)
h.assert_true(context.current_field_kind(instance) == nil, 'inactive editor returned field kind', scope)

local inactive_color_instance = {
  state = {
    scene = { name = 'search' },
    field_editor = { field = 'fg' },
  },
}
h.assert_true(
  context.current_color_dynamic(inactive_color_instance) == nil,
  'inactive editor required result state for color dynamic lookup',
  scope
)
h.assert_true(
  not context.color_field_is_dynamic(inactive_color_instance),
  'inactive editor treated color field as dynamic',
  scope
)

engine.clear('HlcraftUiContextNormal')
dynamic_runtime.reset()
h.cleanup_dir(persist_dir)
config.setup({})

print('hlcraft ui context: OK')
