local h = require('tests.helpers')
local scope = 'hlcraft ui dynamic preview'

local timers = require('hlcraft.core.timers')
local dynamic_preview = require('hlcraft.ui.dynamic_preview')
local ui_state = require('hlcraft.ui.state')

local assert_fails = h.scoped_assert_fails(scope)

h.with_temp_buf(function(preview_buf)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { 'XXXX YYYY' })
  local preview_ns = vim.api.nvim_create_namespace('hlcraft-ui-dynamic-preview-test')
  local preview_instance = {
    ns = preview_ns,
    state = {
      buf = preview_buf,
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }
  local preview_dynamic = {
    version = 1,
    duration = 1000,
    loop = 'once',
    timeline = {
      { at = 0, color = 'base' },
      { at = 1, color = '#ffffff' },
    },
  }
  local preview_id = dynamic_preview.register(preview_instance, {
    line = 1,
    col_start = 0,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = preview_dynamic,
    now_ms = 500,
    extra = true,
  })
  h.assert_equal(preview_id, 1, 'preview item was not registered', scope)
  h.assert_true(preview_instance.state.dynamic_preview.items[1].extra == nil, 'preview item kept unknown state', scope)

  local context_preview_id = dynamic_preview.register(preview_instance, {
    line = 1,
    col_start = 5,
    col_end = 9,
    text = 'YYYY',
    base = '#000000',
    context = {
      bg = '#ffffff',
    },
    dynamic = {
      version = 1,
      duration = 1000,
      loop = 'once',
      timeline = {
        { at = 0, color = 'base' },
        { at = 1, color = 'bg' },
      },
    },
    now_ms = 500,
  })
  h.assert_equal(context_preview_id, 2, 'context preview item was not registered', scope)

  assert_fails(function()
    dynamic_preview.register(nil, {})
  end, 'dynamic preview accepted missing instance')
  local missing_preview_state_ok = pcall(dynamic_preview.register, {
    ns = preview_ns,
    state = {
      buf = preview_buf,
    },
  }, {
    line = 1,
    col_start = 0,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = preview_dynamic,
  })
  h.assert_true(not missing_preview_state_ok, 'dynamic preview accepted missing state schema', scope)
  local non_sequence_preview_state_ok = pcall(dynamic_preview.register, {
    ns = preview_ns,
    state = {
      buf = preview_buf,
      dynamic_preview = {
        marks = {},
        items = {
          [2] = {},
        },
      },
    },
  }, {
    line = 1,
    col_start = 0,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = preview_dynamic,
  })
  h.assert_true(not non_sequence_preview_state_ok, 'dynamic preview accepted non-sequence items state', scope)
  assert_fails(function()
    dynamic_preview.register({
      ns = false,
      state = {
        buf = preview_buf,
        dynamic_preview = ui_state.dynamic_preview(),
      },
    }, {
      line = 1,
      col_start = 0,
      col_end = 4,
      text = 'XXXX',
      base = '#000000',
      dynamic = preview_dynamic,
    })
  end, 'dynamic preview accepted invalid namespace')

  h.assert_true(dynamic_preview.register(preview_instance, {
    line = 1,
    col_start = 0,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = {
      version = 1,
      timeline = {},
    },
  }) == nil, 'invalid dynamic preview item was registered', scope)
  h.assert_true(dynamic_preview.register(preview_instance, {
    line = 0,
    col_start = 0,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = preview_dynamic,
  }) == nil, 'invalid preview geometry was registered', scope)
  h.assert_true(dynamic_preview.register(preview_instance, {
    line = 1,
    col_start = 4,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = preview_dynamic,
  }) == nil, 'invalid preview columns were registered', scope)
  h.assert_true(dynamic_preview.register(preview_instance, {
    line = 1,
    col_start = 0.5,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = preview_dynamic,
  }) == nil, 'fractional preview column was registered', scope)

  assert_fails(function()
    dynamic_preview.tick(preview_instance, math.huge)
  end, 'dynamic preview accepted infinite tick time')
  dynamic_preview.tick(preview_instance, 0)
  local preview_hl_name = ('HlcraftDynamicPreview_%s_%d'):format(
    tostring(preview_instance.state.dynamic_preview.instance_id),
    preview_id
  )
  local first_preview_hl = vim.api.nvim_get_hl(preview_ns, { name = preview_hl_name })
  h.assert_equal(first_preview_hl.fg, 0x808080, 'fixed preview did not sample requested phase', scope)
  local context_preview_hl_name = ('HlcraftDynamicPreview_%s_%d'):format(
    tostring(preview_instance.state.dynamic_preview.instance_id),
    context_preview_id
  )
  local context_preview_hl = vim.api.nvim_get_hl(preview_ns, { name = context_preview_hl_name })
  h.assert_equal(context_preview_hl.fg, 0x808080, 'context preview did not resolve channel color refs', scope)
  dynamic_preview.tick(preview_instance, 1000)
  local second_preview_hl = vim.api.nvim_get_hl(preview_ns, { name = preview_hl_name })
  h.assert_equal(second_preview_hl.fg, 0x808080, 'fixed preview changed with live time', scope)

  preview_instance.state.dynamic_preview.marks[preview_id] = false
  assert_fails(function()
    dynamic_preview.tick(preview_instance, 0)
  end, 'dynamic preview accepted invalid mark id state')
  preview_instance.state.dynamic_preview.marks = {
    bad = 1,
  }
  assert_fails(function()
    dynamic_preview.tick(preview_instance, 0)
  end, 'dynamic preview accepted invalid mark item id state')
  preview_instance.state.dynamic_preview.marks = {}
  preview_instance.state.dynamic_preview.items = {
    [2] = preview_instance.state.dynamic_preview.items[1],
  }
  assert_fails(function()
    dynamic_preview.tick(preview_instance, 0)
  end, 'dynamic preview tick accepted non-sequence items state')
  preview_instance.state.dynamic_preview.items = {}
  dynamic_preview.clear(preview_instance)
end)

h.with_temp_buf(function(preview_buf)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { 'XXXX' })
  local preview_ns = vim.api.nvim_create_namespace('hlcraft-ui-dynamic-preview-reset-test')
  local preview_instance = {
    ns = preview_ns,
    state = {
      buf = preview_buf,
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }

  local function register_preview()
    return dynamic_preview.register(preview_instance, {
      line = 1,
      col_start = 0,
      col_end = 4,
      text = 'XXXX',
      base = '#000000',
      dynamic = {
        version = 1,
        duration = 1000,
        loop = 'once',
        timeline = {
          { at = 0, color = 'base' },
        },
      },
    })
  end

  local preview_id = register_preview()
  h.assert_equal(preview_id, 1, 'dynamic preview reset did not register an item', scope)
  dynamic_preview.tick(preview_instance, 0)
  h.assert_true(
    #vim.api.nvim_buf_get_extmarks(preview_buf, preview_ns, 0, -1, {}) > 0,
    'dynamic preview reset did not create a mark',
    scope
  )

  dynamic_preview.clear(preview_instance)
  h.assert_equal(
    #vim.api.nvim_buf_get_extmarks(preview_buf, preview_ns, 0, -1, {}),
    0,
    'dynamic preview item reset kept rendered marks',
    scope
  )
  h.assert_true(next(preview_instance.state.dynamic_preview.items) == nil, 'dynamic preview reset kept items', scope)
  h.assert_true(
    next(preview_instance.state.dynamic_preview.marks) == nil,
    'dynamic preview reset kept mark state',
    scope
  )

  local next_preview_id = register_preview()
  h.assert_equal(next_preview_id, 1, 'dynamic preview mark reset did not register an item', scope)
  dynamic_preview.tick(preview_instance, 0)
  h.assert_true(
    #vim.api.nvim_buf_get_extmarks(preview_buf, preview_ns, 0, -1, {}) > 0,
    'dynamic preview mark reset did not create a mark',
    scope
  )

  dynamic_preview.reset_marks(preview_instance)
  h.assert_equal(
    #vim.api.nvim_buf_get_extmarks(preview_buf, preview_ns, 0, -1, {}),
    0,
    'dynamic preview mark reset kept rendered marks',
    scope
  )
  h.assert_true(
    next(preview_instance.state.dynamic_preview.items) ~= nil,
    'dynamic preview mark reset cleared items',
    scope
  )
  h.assert_true(
    next(preview_instance.state.dynamic_preview.marks) == nil,
    'dynamic preview mark reset kept mark state',
    scope
  )

  local preserved_preview_id = register_preview()
  dynamic_preview.tick(preview_instance, 0)
  local preserved_items = preview_instance.state.dynamic_preview.items
  local preserved_marks = preview_instance.state.dynamic_preview.marks
  local original_del_extmark = vim.api.nvim_buf_del_extmark
  vim.api.nvim_buf_del_extmark = function()
    error('delete extmark failed')
  end
  dynamic_preview.clear(preview_instance)
  vim.api.nvim_buf_del_extmark = original_del_extmark
  h.assert_equal(
    preview_instance.state.dynamic_preview.items,
    preserved_items,
    'failed dynamic preview mark cleanup dropped items',
    scope
  )
  h.assert_equal(
    preview_instance.state.dynamic_preview.marks,
    preserved_marks,
    'failed dynamic preview mark cleanup dropped mark state',
    scope
  )
  h.assert_true(
    #vim.api.nvim_buf_get_extmarks(preview_buf, preview_ns, 0, -1, {}) > 0,
    'failed dynamic preview mark cleanup deleted test mark unexpectedly',
    scope
  )
  dynamic_preview.clear(preview_instance)
  h.assert_true(
    preview_instance.state.dynamic_preview.items[preserved_preview_id] == nil,
    'dynamic preview mark cleanup retry kept item state',
    scope
  )

  register_preview()
  dynamic_preview.tick(preview_instance, 0)
  local tick_preserved_marks = preview_instance.state.dynamic_preview.marks
  vim.api.nvim_buf_del_extmark = function()
    error('delete extmark failed')
  end
  dynamic_preview.tick(preview_instance, 0)
  vim.api.nvim_buf_del_extmark = original_del_extmark
  h.assert_equal(
    preview_instance.state.dynamic_preview.marks,
    tick_preserved_marks,
    'failed dynamic preview tick cleanup replaced mark state',
    scope
  )
  dynamic_preview.clear(preview_instance)
end)

h.with_temp_buf(function(preview_buf)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { 'XXXX' })
  local preview_ns = vim.api.nvim_create_namespace('hlcraft-ui-dynamic-preview-timer-test')
  local preview_instance = {
    ns = preview_ns,
    state = {
      buf = preview_buf,
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }

  dynamic_preview.register(preview_instance, {
    line = 1,
    col_start = 0,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = {
      version = 1,
      duration = 1000,
      loop = 'once',
      timeline = {
        { at = 0, color = 'base' },
      },
    },
  })

  local scheduled_tick
  local original_repeating = timers.repeating
  local original_schedule = vim.schedule
  local cleanup_failed = true
  timers.repeating = function(_, callback)
    scheduled_tick = callback
    return {
      stop = function() end,
      close = function()
        if cleanup_failed then
          error('timer close failed')
        end
      end,
    }
  end
  vim.schedule = function(callback)
    callback()
  end

  dynamic_preview.sync(preview_instance)
  preview_instance.state.dynamic_preview.items = {
    [2] = preview_instance.state.dynamic_preview.items[1],
  }
  local notifications = {}
  local tick_ok = h.with_notify_stub(function()
    return pcall(scheduled_tick)
  end, function(message)
    notifications[#notifications + 1] = message
  end)
  local timer_preserved = preview_instance.state.dynamic_preview.timer ~= nil

  timers.repeating = original_repeating
  vim.schedule = original_schedule
  cleanup_failed = false
  preview_instance.state.dynamic_preview.items = {}
  dynamic_preview.clear(preview_instance)

  h.assert_true(tick_ok, 'dynamic preview timer error escaped scheduled callback', scope)
  h.assert_true(timer_preserved, 'dynamic preview timer error dropped a failed cleanup handle', scope)
  h.assert_true(
    notifications[1]
      and notifications[1]:find('dynamic preview timer', 1, true) ~= nil
      and notifications[1]:find('timer cleanup failed', 1, true) ~= nil,
    'dynamic preview timer error did not report cleanup failure',
    scope
  )
end)

h.with_temp_buf(function(preview_buf)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { 'XXXX' })
  local preview_ns = vim.api.nvim_create_namespace('hlcraft-ui-dynamic-preview-start-failure-test')
  local preview_instance = {
    ns = preview_ns,
    state = {
      buf = preview_buf,
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }

  dynamic_preview.register(preview_instance, {
    line = 1,
    col_start = 0,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = {
      version = 1,
      duration = 1000,
      loop = 'repeat',
      timeline = {
        { at = 0, color = 'base' },
      },
    },
  })

  local original_repeating = timers.repeating
  timers.repeating = function()
    return nil
  end
  local notifications = {}
  local sync_result = h.with_notify_stub(function()
    return dynamic_preview.sync(preview_instance)
  end, function(message)
    notifications[#notifications + 1] = message
  end)
  timers.repeating = original_repeating
  dynamic_preview.clear(preview_instance)

  h.assert_equal(sync_result, false, 'dynamic preview sync ignored timer start failure', scope)
  h.assert_true(preview_instance.state.dynamic_preview.timer == nil, 'failed timer start kept timer state', scope)
  h.assert_true(
    notifications[1] and notifications[1]:find('dynamic preview timer', 1, true) ~= nil,
    'dynamic preview timer start failure was not notified',
    scope
  )
end)

h.with_temp_buf(function(preview_buf)
  vim.api.nvim_buf_set_lines(preview_buf, 0, -1, false, { 'XXXX YYYY' })
  local preview_ns = vim.api.nvim_create_namespace('hlcraft-ui-dynamic-preview-stale-timer-test')
  local preview_instance = {
    ns = preview_ns,
    state = {
      buf = preview_buf,
      dynamic_preview = ui_state.dynamic_preview(),
    },
  }
  local preview_dynamic = {
    version = 1,
    duration = 1000,
    loop = 'repeat',
    timeline = {
      { at = 0, color = 'base' },
      { at = 1, color = '#ffffff' },
    },
  }

  dynamic_preview.register(preview_instance, {
    line = 1,
    col_start = 0,
    col_end = 4,
    text = 'XXXX',
    base = '#000000',
    dynamic = preview_dynamic,
  })

  local scheduled_tick
  local stopped = 0
  local closed = 0
  local original_repeating = timers.repeating
  local original_schedule = vim.schedule
  timers.repeating = function(_, callback)
    scheduled_tick = callback
    return {
      stop = function()
        stopped = stopped + 1
      end,
      close = function()
        closed = closed + 1
      end,
    }
  end
  vim.schedule = function(callback)
    callback()
  end

  dynamic_preview.sync(preview_instance)
  local old_preview = preview_instance.state.dynamic_preview
  preview_instance.state.dynamic_preview = ui_state.dynamic_preview()
  dynamic_preview.register(preview_instance, {
    line = 1,
    col_start = 5,
    col_end = 9,
    text = 'YYYY',
    base = '#000000',
    dynamic = preview_dynamic,
  })
  local stale_tick_ok = pcall(scheduled_tick)

  timers.repeating = original_repeating
  vim.schedule = original_schedule
  dynamic_preview.clear(preview_instance)

  h.assert_true(stale_tick_ok, 'stale dynamic preview timer escaped callback', scope)
  h.assert_true(old_preview.timer == nil, 'stale dynamic preview timer kept old timer state', scope)
  h.assert_equal(stopped, 1, 'stale dynamic preview timer was not stopped', scope)
  h.assert_equal(closed, 1, 'stale dynamic preview timer was not closed', scope)
  h.assert_equal(
    #vim.api.nvim_buf_get_extmarks(preview_buf, preview_ns, 0, -1, {}),
    0,
    'stale dynamic preview timer rendered replacement preview',
    scope
  )
end)

print('hlcraft ui dynamic preview: OK')
