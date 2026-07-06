local h = require('tests.helpers')
local scope = 'hlcraft ui dynamic preview'

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

print('hlcraft ui dynamic preview: OK')
