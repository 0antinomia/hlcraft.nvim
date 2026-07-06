local h = require('tests.helpers')
local scope = 'hlcraft ui session'

local service_module = 'hlcraft.engine.service'
local session_module = 'hlcraft.ui.session'
local original_service = package.loaded[service_module]
local original_session = package.loaded[session_module]

local saved = false
local restored_name
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
    return clean_draft
  end,
  get_persisted = function(name)
    if name == 'invalid-persisted' then
      return nil
    end
    return clean_persisted
  end,
  get_draft_group = function(name)
    return name == 'dirty' and 'draft' or 'main'
  end,
  get_persisted_group = function(name)
    return name == 'dirty' and 'persisted' or 'main'
  end,
  set_color = function()
    return true, nil
  end,
  set_dynamic = function()
    return true, nil
  end,
  set_style = function()
    return true, nil
  end,
  set_group = function()
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
