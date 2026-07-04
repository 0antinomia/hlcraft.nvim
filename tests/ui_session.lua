local h = require('tests.helpers')
local scope = 'hlcraft ui session'

local service_module = 'hlcraft.engine.service'
local session_module = 'hlcraft.ui.session'
local original_service = package.loaded[service_module]
local original_session = package.loaded[session_module]

local saved = false
local restored_name

local fake_engine = {
  get = function(name)
    if name == 'invalid-draft' then
      return nil
    end
    if name == 'dirty' then
      return { fg = '#202020' }
    end
    return { fg = '#101010' }
  end,
  get_persisted = function(name)
    if name == 'invalid-persisted' then
      return nil
    end
    return { fg = '#101010' }
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
h.assert_equal(session.draft_entry('clean').fg, '#101010', 'draft entry was not copied', scope)
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
local bad_draft_ok = pcall(session.draft_entry, 'invalid-draft')
h.assert_true(not bad_draft_ok, 'session accepted invalid draft entry', scope)
local bad_persisted_ok = pcall(session.persisted_entry, 'invalid-persisted')
h.assert_true(not bad_persisted_ok, 'session accepted invalid persisted entry', scope)
local bad_save_name_ok = pcall(session.save, {}, nil)
h.assert_true(not bad_save_name_ok, 'session save accepted nil highlight name', scope)

package.loaded[session_module] = original_session
package.loaded[service_module] = original_service

print('hlcraft ui session: OK')
