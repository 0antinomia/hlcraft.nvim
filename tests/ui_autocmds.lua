local h = require('tests.helpers')
local scope = 'hlcraft ui autocmds'

local autocmds = require('hlcraft.ui.autocmds')
local config = require('hlcraft.config')
local ui_state = require('hlcraft.ui.state')

local assert_fails = h.scoped_assert_fails(scope)

local function set_input_marks(instance, name, start_row, end_boundary_row)
  instance.state.extmark_ids[name .. ':start'] =
    vim.api.nvim_buf_set_extmark(instance.state.buf, instance.ns, start_row, 0, {
      right_gravity = false,
    })
  instance.state.extmark_ids[name .. ':end'] =
    vim.api.nvim_buf_set_extmark(instance.state.buf, instance.ns, end_boundary_row, 0, {
      right_gravity = false,
    })
end

h.with_temp_buf(function(buf)
  config.setup({
    search = {
      debounce_ms = 0,
    },
  })
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { 'name query', 'color query', '' })

  assert_fails(function()
    autocmds.setup(nil)
  end, 'workspace autocmds accepted missing instance')
  assert_fails(function()
    autocmds.setup({
      group_name = '',
      state = {
        buf = buf,
      },
      rerender = function() end,
      cleanup = function() end,
    })
  end, 'workspace autocmds accepted empty group name')
  assert_fails(function()
    autocmds.setup({
      group_name = 'HlcraftUiAutocmdsInvalidBuffer',
      state = {},
      rerender = function() end,
      cleanup = function() end,
    })
  end, 'workspace autocmds accepted missing buffer')
  assert_fails(function()
    autocmds.setup({
      group_name = 'HlcraftUiAutocmdsMissingCallbacks',
      state = {
        buf = buf,
      },
    })
  end, 'workspace autocmds accepted missing callbacks')

  local rerenders = 0
  local instance = {
    group_name = 'HlcraftUiAutocmdsTest' .. tostring(buf),
    ns = vim.api.nvim_create_namespace('hlcraft-ui-autocmds-test'),
    state = {
      buf = buf,
      extmark_ids = {},
      geometry = ui_state.geometry(),
      name_query = '',
      color_query = '',
    },
    rerender = function()
      rerenders = rerenders + 1
    end,
    cleanup = function() end,
  }
  instance.state.geometry.inputs = {
    { name = 'name', kind = 'name', line = 1 },
    { name = 'color', kind = 'color', line = 2 },
  }
  set_input_marks(instance, 'name', 0, 1)
  set_input_marks(instance, 'color', 1, 2)

  autocmds.setup(instance)
  vim.api.nvim_exec_autocmds('TextChanged', {
    group = instance.group,
    buffer = buf,
    modeline = false,
  })

  h.assert_equal(instance.state.name_query, 'name query', 'name query was not synced immediately', scope)
  h.assert_equal(instance.state.color_query, 'color query', 'color query was not synced immediately', scope)
  h.assert_equal(rerenders, 1, 'immediate debounce path did not rerender once', scope)
  h.assert_true(instance.state.debounce_timer == nil, 'immediate debounce path created a timer', scope)

  vim.api.nvim_del_augroup_by_id(instance.group)
  config.setup({})
end)

print('hlcraft ui autocmds: OK')
