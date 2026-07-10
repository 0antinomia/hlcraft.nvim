local h = require('tests.helpers')
local scope = 'hlcraft ui session'

local service_module = 'hlcraft.engine.service'
local session_module = 'hlcraft.ui.session'
local original_service = package.loaded[service_module]
local original_session = package.loaded[session_module]

local saved = false
local restored_name
local refresh_fail_draft = {
  fg = '#101010',
  dynamic = {
    fg = {
      version = 1,
      duration = 1000,
      loop = 'repeat',
      timeline = {
        { at = 0, color = 'base' },
      },
    },
  },
}
local refresh_fail_group = 'old-group'
local rollback_fail_draft = {
  fg = '#101010',
}
local discard_fail_draft = {
  fg = '#303030',
  bold = true,
  dynamic = {
    fg = {
      version = 1,
      duration = 1400,
      loop = 'repeat',
      timeline = {
        { at = 0, color = 'base' },
      },
    },
  },
}
local discard_fail_group = 'discard-draft'
local discard_fail_persisted = {
  bg = '#404040',
}
local discard_fail_persisted_group = 'discard-persisted'
local clean_draft = {
  fg = '#101010',
  dynamic = {
    fg = {
      version = 1,
      duration = 2000,
      loop = 'repeat',
      interpolation = 'linear',
      timeline = {
        { at = 0, color = '#000000' },
        { at = 1, color = '#ffffff' },
      },
    },
  },
}
local clean_persisted = vim.deepcopy(clean_draft)

local fake_engine = {
  get = function(name)
    if name == 'invalid-draft' then
      return nil
    end
    if name == 'dirty' then
      return { fg = '#202020' }
    end
    if name == 'invalid-dynamic' then
      return {
        dynamic = {
          fg = {
            version = 1,
            timeline = {},
          },
        },
      }
    end
    if name == 'refresh-fail' then
      return refresh_fail_draft
    end
    if name == 'discard-refresh-fail' then
      return discard_fail_draft
    end
    return clean_draft
  end,
  get_persisted = function(name)
    if name == 'invalid-persisted' then
      return nil
    end
    if name == 'discard-refresh-fail' then
      return discard_fail_persisted
    end
    return clean_persisted
  end,
  get_draft_group = function(name)
    if name == 'refresh-fail' then
      return refresh_fail_group
    end
    if name == 'discard-refresh-fail' then
      return discard_fail_group
    end
    return name == 'dirty' and 'draft' or 'main'
  end,
  get_persisted_group = function(name)
    if name == 'discard-refresh-fail' then
      return discard_fail_persisted_group
    end
    return name == 'dirty' and 'persisted' or 'main'
  end,
  set_color = function(name, _, value)
    if name == 'refresh-fail' then
      refresh_fail_draft.fg = value
    end
    if name == 'rollback-fail' then
      if value == '#101010' then
        return false, 'rollback set_color failed'
      end
      rollback_fail_draft.fg = value
    end
    return true, nil
  end,
  set_dynamic = function(name, key, dynamic)
    if name == 'refresh-fail' then
      if refresh_fail_draft.dynamic == nil then
        refresh_fail_draft.dynamic = {}
      end
      refresh_fail_draft.dynamic[key] = dynamic
    end
    return true, nil
  end,
  set_style = function()
    return true, nil
  end,
  set_group = function(name, group)
    if name == 'refresh-fail' then
      refresh_fail_group = group
    end
    return true, nil
  end,
  set_blend = function()
    return true, nil
  end,
  save = function()
    saved = true
    return true, nil
  end,
  restore_persisted = function(name)
    restored_name = name
    if name == 'discard-refresh-fail' then
      discard_fail_draft = vim.deepcopy(discard_fail_persisted)
      discard_fail_group = discard_fail_persisted_group
    end
  end,
  apply_patch = function(name, patch)
    if name == 'discard-refresh-fail' then
      local restored = {}
      for key, value in pairs(patch) do
        if key ~= 'group' and key ~= 'dynamic' and value ~= vim.NIL then
          restored[key] = value
        end
      end
      if type(patch.dynamic) == 'table' then
        for key, value in pairs(patch.dynamic) do
          if value ~= vim.NIL then
            restored.dynamic = restored.dynamic or {}
            restored.dynamic[key] = value
          end
        end
      end
      discard_fail_draft = restored
      discard_fail_group = patch.group == vim.NIL and nil or patch.group
    end
    return true, nil
  end,
  known_groups = function()
    return { 'main' }
  end,
  file_path = function(name)
    return '/tmp/' .. name .. '.toml'
  end,
}

package.loaded[session_module] = nil
package.loaded[service_module] = fake_engine
local session = require(session_module)

local draft = session.draft_entry('clean')
draft.fg = '#ffffff'
draft.dynamic.fg.timeline[1].color = '#222222'
h.assert_equal(session.draft_entry('clean').fg, '#101010', 'draft entry was not copied', scope)
h.assert_equal(
  session.draft_entry('clean').dynamic.fg.timeline[1].color,
  '#000000',
  'draft entry nested dynamic config was not copied',
  scope
)
h.assert_equal(session.display_value('clean', 'fg', '#fallback'), '#101010', 'display value ignored draft entry', scope)
h.assert_equal(session.display_value('clean', 'bg', '#fallback'), '#fallback', 'display value ignored fallback', scope)
h.assert_true(not session.is_dirty('clean'), 'clean session was marked dirty', scope)
h.assert_true(session.is_dirty('dirty'), 'dirty session was not detected', scope)
h.assert_equal(session.file_path('clean'), '/tmp/clean.toml', 'session file path changed', scope)

local save_ok, save_err = session.save({ rerender = function() end }, 'clean')
h.assert_true(save_ok, save_err or 'session save failed', scope)
h.assert_true(saved, 'session save did not call engine save', scope)
session.discard({ rerender = function() end }, 'clean')
h.assert_equal(restored_name, 'clean', 'session discard did not restore persisted state', scope)
local refresh_failure_instance = {
  rerender = function()
    error('render failed')
  end,
}
saved = false
local save_refresh_ok, save_refresh_err = session.save(refresh_failure_instance, 'clean')
h.assert_true(not save_refresh_ok, 'session save accepted failed refresh', scope)
h.assert_true(saved, 'session save refresh failure skipped engine save', scope)
h.assert_true(
  tostring(save_refresh_err):find('render failed', 1, true) ~= nil,
  'session save refresh failure dropped refresh error',
  scope
)
local refresh_color_ok = pcall(session.set_color, refresh_failure_instance, 'refresh-fail', 'fg', '#202020')
h.assert_true(not refresh_color_ok, 'session set_color accepted failed refresh', scope)
h.assert_equal(refresh_fail_draft.fg, '#101010', 'failed session set_color changed draft', scope)
local rollback_failure_ok, rollback_failure_err =
  pcall(session.set_color, refresh_failure_instance, 'rollback-fail', 'fg', '#202020')
h.assert_true(not rollback_failure_ok, 'session set_color accepted failed refresh rollback', scope)
h.assert_true(
  tostring(rollback_failure_err):find('render failed', 1, true) ~= nil,
  'session refresh rollback failure dropped original refresh error',
  scope
)
h.assert_true(
  tostring(rollback_failure_err):find('rollback set_color failed', 1, true) ~= nil,
  'session refresh rollback failure dropped rollback error',
  scope
)
h.assert_equal(rollback_fail_draft.fg, '#202020', 'failed session rollback changed draft unexpectedly', scope)

local restore_refresh_buf = vim.api.nvim_create_buf(false, true)
local restore_refresh_instance = {
  state = {
    buf = restore_refresh_buf,
  },
  rerender = function()
    vim.api.nvim_buf_set_lines(restore_refresh_buf, 0, -1, false, { refresh_fail_draft.fg })
    if refresh_fail_draft.fg == '#202020' then
      error('render failed')
    end
  end,
}
local restore_refresh_ok = pcall(session.set_color, restore_refresh_instance, 'refresh-fail', 'fg', '#202020')
h.assert_true(not restore_refresh_ok, 'session set_color accepted failed refresh with partial UI write', scope)
h.assert_equal(refresh_fail_draft.fg, '#101010', 'failed session restore refresh changed draft', scope)
h.assert_equal(
  table.concat(vim.api.nvim_buf_get_lines(restore_refresh_buf, 0, -1, false), '\n'),
  '#101010',
  'failed session restore refresh left partially rendered draft value',
  scope
)
vim.api.nvim_buf_delete(restore_refresh_buf, { force = true })

local refresh_dynamic_ok = pcall(session.set_dynamic, refresh_failure_instance, 'refresh-fail', 'fg', {
  version = 1,
  duration = 2500,
  loop = 'pingpong',
  timeline = {
    { at = 0, color = '#ffffff' },
  },
})
h.assert_true(not refresh_dynamic_ok, 'session set_dynamic accepted failed refresh', scope)
h.assert_equal(refresh_fail_draft.dynamic.fg.duration, 1000, 'failed session set_dynamic changed draft', scope)
local refresh_group_ok = pcall(session.set_group, refresh_failure_instance, 'refresh-fail', 'new-group')
h.assert_true(not refresh_group_ok, 'session set_group accepted failed refresh', scope)
h.assert_equal(refresh_fail_group, 'old-group', 'failed session set_group changed draft group', scope)
local before_discard_fail_draft = vim.deepcopy(discard_fail_draft)
local before_discard_fail_group = discard_fail_group
local refresh_discard_ok = pcall(session.discard, refresh_failure_instance, 'discard-refresh-fail')
h.assert_true(not refresh_discard_ok, 'session discard accepted failed refresh', scope)
h.assert_true(
  vim.deep_equal(discard_fail_draft, before_discard_fail_draft),
  'failed session discard changed draft',
  scope
)
h.assert_equal(discard_fail_group, before_discard_fail_group, 'failed session discard changed draft group', scope)

local bad_name_ok = pcall(session.draft_entry, nil)
h.assert_true(not bad_name_ok, 'session accepted nil highlight name', scope)
local empty_name_ok = pcall(session.draft_entry, '')
h.assert_true(not empty_name_ok, 'session accepted empty highlight name', scope)
local bad_display_key_ok = pcall(session.display_value, 'clean', nil, '#fallback')
h.assert_true(not bad_display_key_ok, 'session display accepted nil field key', scope)
local empty_field_key_ok = pcall(session.field_value, 'clean', '')
h.assert_true(not empty_field_key_ok, 'session field value accepted empty field key', scope)
local bad_dynamic_key_ok = pcall(session.dynamic_value, 'clean', false)
h.assert_true(not bad_dynamic_key_ok, 'session dynamic value accepted non-string field key', scope)
local bad_draft_ok = pcall(session.draft_entry, 'invalid-draft')
h.assert_true(not bad_draft_ok, 'session accepted invalid draft entry', scope)
local bad_persisted_ok = pcall(session.persisted_entry, 'invalid-persisted')
h.assert_true(not bad_persisted_ok, 'session accepted invalid persisted entry', scope)
local bad_dynamic_ok = pcall(session.dynamic_value, 'invalid-dynamic', 'fg')
h.assert_true(not bad_dynamic_ok, 'session accepted invalid dynamic entry', scope)
local bad_save_name_ok = pcall(session.save, {}, nil)
h.assert_true(not bad_save_name_ok, 'session save accepted nil highlight name', scope)
local bad_set_color_key_ok = pcall(session.set_color, { rerender = function() end }, 'clean', '', '#ffffff')
h.assert_true(not bad_set_color_key_ok, 'session set_color accepted empty field key', scope)
local bad_set_dynamic_key_ok = pcall(session.set_dynamic, { rerender = function() end }, 'clean', false, nil)
h.assert_true(not bad_set_dynamic_key_ok, 'session set_dynamic accepted non-string field key', scope)
local bad_set_style_key_ok = pcall(session.set_style, { rerender = function() end }, 'clean', '', true)
h.assert_true(not bad_set_style_key_ok, 'session set_style accepted empty field key', scope)
saved = false
local bad_save_instance_ok = pcall(session.save, {}, 'clean')
h.assert_true(not bad_save_instance_ok, 'session save accepted invalid refresh target', scope)
h.assert_true(not saved, 'session save mutated engine before refresh target validation', scope)
restored_name = nil
local bad_discard_instance_ok = pcall(session.discard, {
  state = false,
  rerender = function() end,
}, 'clean')
h.assert_true(not bad_discard_instance_ok, 'session discard accepted invalid refresh state', scope)
h.assert_true(restored_name == nil, 'session discard mutated engine before refresh target validation', scope)

package.loaded[session_module] = original_session
package.loaded[service_module] = original_service

print('hlcraft ui session: OK')
