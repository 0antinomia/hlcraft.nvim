local h = require('tests.helpers')
local scope = 'hlcraft ui help'

local help = require('hlcraft.ui.help')
local handles = require('hlcraft.ui.handles')

local assert_fails = h.scoped_assert_fails(scope)

local instance = {
  ns = vim.api.nvim_create_namespace('hlcraft-ui-help-test'),
  state = {
    help_buf = nil,
    help_win = nil,
  },
}

local ok, err = xpcall(function()
  h.assert_true(not help.is_open(instance), 'fresh help window reported open', scope)
  assert_fails(function()
    help.is_open(nil)
  end, 'help is_open accepted missing instance')
  assert_fails(function()
    help.ensure_buffer(nil)
  end, 'help ensure_buffer accepted missing instance')
  assert_fails(function()
    help.close(nil)
  end, 'help close accepted missing instance')
  assert_fails(function()
    help.delete_buffer(nil)
  end, 'help delete_buffer accepted missing instance')
  assert_fails(function()
    help.toggle({
      ns = false,
      state = {},
    })
  end, 'help toggle accepted invalid namespace')

  local buf = help.ensure_buffer(instance)
  h.assert_true(handles.is_valid_buf(buf), 'help buffer was not created', scope)
  h.assert_equal(instance.state.help_buf, buf, 'help buffer handle was not stored', scope)
  h.assert_equal(help.ensure_buffer(instance), buf, 'help buffer was not reused', scope)

  help.toggle(instance)
  h.assert_true(help.is_open(instance), 'help toggle did not open window', scope)
  h.assert_true(handles.is_valid_win(instance.state.help_win), 'help window handle is invalid', scope)
  h.assert_equal(vim.api.nvim_win_get_buf(instance.state.help_win), buf, 'help window opened the wrong buffer', scope)

  help.toggle(instance)
  h.assert_true(not help.is_open(instance), 'help toggle did not close window', scope)
  h.assert_true(instance.state.help_win == nil, 'help close kept window handle', scope)

  help.delete_buffer(instance)
  h.assert_true(instance.state.help_buf == nil, 'help delete kept buffer handle', scope)
end, debug.traceback)

help.close(instance)
help.delete_buffer(instance)

if not ok then
  error(err, 0)
end

print('hlcraft ui help: OK')
