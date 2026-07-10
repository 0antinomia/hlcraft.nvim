local h = require('tests.helpers')
local scope = 'hlcraft ui autocmds'

local autocmds = require('hlcraft.ui.autocmds')
local config = require('hlcraft.config')
local ui_state = require('hlcraft.ui.state')

local assert_fails = h.scoped_assert_fails(scope)

local function set_input_marks(instance, name, start_row, end_boundary_row)
  local ns = instance.input_ns or instance.ns
  instance.state.extmark_ids[name .. ':start'] = vim.api.nvim_buf_set_extmark(instance.state.buf, ns, start_row, 0, {
    right_gravity = false,
  })
  instance.state.extmark_ids[name .. ':end'] =
    vim.api.nvim_buf_set_extmark(instance.state.buf, ns, end_boundary_row, 0, {
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

  local failing_setup_instance = {
    group_name = 'HlcraftUiAutocmdsSetupFailure' .. tostring(buf),
    ns = vim.api.nvim_create_namespace('hlcraft-ui-autocmds-setup-failure-test'),
    state = {
      buf = buf,
      extmark_ids = {},
      geometry = ui_state.geometry(),
      name_query = '',
      color_query = '',
    },
    rerender = function() end,
    cleanup = function() end,
  }
  local original_create_augroup = vim.api.nvim_create_augroup
  local original_create_autocmd = vim.api.nvim_create_autocmd
  local created_group
  local create_autocmd_calls = 0
  vim.api.nvim_create_augroup = function(...)
    created_group = original_create_augroup(...)
    return created_group
  end
  vim.api.nvim_create_autocmd = function(...)
    create_autocmd_calls = create_autocmd_calls + 1
    if create_autocmd_calls == 2 then
      error('autocmd failed')
    end
    return original_create_autocmd(...)
  end
  local failing_setup_ok = pcall(autocmds.setup, failing_setup_instance)
  vim.api.nvim_create_augroup = original_create_augroup
  vim.api.nvim_create_autocmd = original_create_autocmd
  h.assert_true(not failing_setup_ok, 'workspace autocmd setup accepted failed registration', scope)
  h.assert_true(failing_setup_instance.group == nil, 'failed workspace autocmd setup kept group state', scope)
  h.assert_true(type(created_group) == 'number', 'failed workspace autocmd setup did not create a test group', scope)
  h.assert_true(not pcall(vim.api.nvim_create_autocmd, 'User', {
    group = created_group,
    pattern = 'HlcraftInvalidGroupProbe',
    callback = function() end,
  }), 'failed workspace autocmd setup leaked its augroup', scope)

  local cleanup_failure_instance = {
    group_name = 'HlcraftUiAutocmdsCleanupFailure' .. tostring(buf),
    ns = vim.api.nvim_create_namespace('hlcraft-ui-autocmds-cleanup-failure-test'),
    state = {
      buf = buf,
      extmark_ids = {},
      geometry = ui_state.geometry(),
      name_query = '',
      color_query = '',
    },
    rerender = function() end,
    cleanup = function() end,
  }
  local cleanup_failure_group
  local original_del_augroup = vim.api.nvim_del_augroup_by_id
  vim.api.nvim_create_augroup = function(...)
    cleanup_failure_group = original_create_augroup(...)
    return cleanup_failure_group
  end
  vim.api.nvim_create_autocmd = function()
    error('autocmd failed')
  end
  vim.api.nvim_del_augroup_by_id = function(group, ...)
    if cleanup_failure_group ~= nil and group == cleanup_failure_group then
      error('autocmd group delete failed')
    end
    return original_del_augroup(group, ...)
  end
  local cleanup_failure_ok, cleanup_failure_err = pcall(autocmds.setup, cleanup_failure_instance)
  vim.api.nvim_create_augroup = original_create_augroup
  vim.api.nvim_create_autocmd = original_create_autocmd
  vim.api.nvim_del_augroup_by_id = original_del_augroup
  local cleanup_failure_kept_group = cleanup_failure_instance.group
  local cleanup_failure_group_exists = cleanup_failure_group ~= nil
    and pcall(vim.api.nvim_get_autocmds, { group = cleanup_failure_group })
  if cleanup_failure_group_exists then
    vim.api.nvim_del_augroup_by_id(cleanup_failure_group)
  end
  cleanup_failure_instance.group = nil
  h.assert_true(not cleanup_failure_ok, 'workspace autocmd setup accepted failed cleanup', scope)
  h.assert_true(cleanup_failure_group_exists, 'autocmd cleanup failure test did not preserve a group', scope)
  h.assert_equal(
    cleanup_failure_kept_group,
    cleanup_failure_group,
    'failed workspace autocmd cleanup dropped the live group handle',
    scope
  )
  h.assert_true(
    tostring(cleanup_failure_err):find('autocmd group delete failed', 1, true) ~= nil,
    'failed workspace autocmd cleanup did not report the group delete error',
    scope
  )

  local stale_group_instance = {
    group_name = 'HlcraftUiAutocmdsStaleGroup' .. tostring(buf),
    ns = vim.api.nvim_create_namespace('hlcraft-ui-autocmds-stale-group-test'),
    input_ns = vim.api.nvim_create_namespace('hlcraft-ui-autocmds-stale-group-input-test'),
    state = {
      buf = buf,
      extmark_ids = {},
      geometry = ui_state.geometry(),
      name_query = '',
      color_query = '',
    },
    rerender = function() end,
    cleanup = function() end,
  }
  stale_group_instance.state.geometry.inputs = {
    { name = 'name', kind = 'name', line = 1 },
    { name = 'color', kind = 'color', line = 2 },
  }
  set_input_marks(stale_group_instance, 'name', 0, 1)
  set_input_marks(stale_group_instance, 'color', 1, 2)
  local stale_group = vim.api.nvim_create_augroup(stale_group_instance.group_name, { clear = true })
  stale_group_instance.group = stale_group
  vim.api.nvim_del_augroup_by_id(stale_group)
  autocmds.setup(stale_group_instance)
  vim.api.nvim_exec_autocmds('TextChanged', {
    group = stale_group_instance.group,
    buffer = buf,
    modeline = false,
  })
  h.assert_equal(
    stale_group_instance.state.name_query,
    'name query',
    'stale workspace autocmd group skipped reinstall',
    scope
  )
  vim.api.nvim_del_augroup_by_id(stale_group_instance.group)

  local rebound_previous_buf = vim.api.nvim_create_buf(false, true)
  local rebound_instance = {
    autocmd_buf = rebound_previous_buf,
    group_name = 'HlcraftUiAutocmdsRebound' .. tostring(buf),
    ns = vim.api.nvim_create_namespace('hlcraft-ui-autocmds-rebound-test'),
    state = {
      buf = buf,
      extmark_ids = {},
      geometry = ui_state.geometry(),
      name_query = '',
      color_query = '',
    },
    rerender = function() end,
    cleanup = function() end,
  }
  rebound_instance.group = vim.api.nvim_create_augroup(rebound_instance.group_name, { clear = true })
  autocmds.setup(rebound_instance)
  local rebound_autocmds = vim.api.nvim_get_autocmds({
    group = rebound_instance.group,
    buffer = buf,
  })
  vim.api.nvim_buf_delete(rebound_previous_buf, { force = true })
  vim.api.nvim_del_augroup_by_id(rebound_instance.group)
  h.assert_true(#rebound_autocmds > 0, 'preserved workspace augroup skipped new buffer registration', scope)

  local rerenders = 0
  local instance = {
    group_name = 'HlcraftUiAutocmdsTest' .. tostring(buf),
    ns = vim.api.nvim_create_namespace('hlcraft-ui-autocmds-test'),
    input_ns = vim.api.nvim_create_namespace('hlcraft-ui-autocmds-input-test'),
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

  instance.state.rendering = true
  local rendering_rerenders = rerenders
  vim.api.nvim_exec_autocmds('TextChanged', {
    group = instance.group,
    buffer = buf,
    modeline = false,
  })
  instance.state.rendering = false
  h.assert_equal(rerenders, rendering_rerenders, 'rendering TextChanged rerendered immediately', scope)
  h.assert_true(instance.state.debounce_timer == nil, 'rendering TextChanged created an immediate timer', scope)

  local throwing_instance = {
    group_name = 'HlcraftUiAutocmdsThrowing' .. tostring(buf),
    ns = instance.ns,
    input_ns = instance.input_ns,
    state = {
      buf = buf,
      extmark_ids = {},
      geometry = ui_state.geometry(),
      name_query = '',
      color_query = '',
    },
    rerender = function()
      error('render exploded')
    end,
    cleanup = function() end,
  }
  throwing_instance.state.geometry.inputs = vim.deepcopy(instance.state.geometry.inputs)
  set_input_marks(throwing_instance, 'name', 0, 1)
  set_input_marks(throwing_instance, 'color', 1, 2)
  autocmds.setup(throwing_instance)
  local notifications = {}
  local throwing_autocmd_ok = h.with_notify_stub(function()
    return pcall(vim.api.nvim_exec_autocmds, 'TextChanged', {
      group = throwing_instance.group,
      buffer = buf,
      modeline = false,
    })
  end, function(message)
    notifications[#notifications + 1] = message
  end)
  h.assert_true(throwing_autocmd_ok, 'workspace autocmd rerender error escaped the callback', scope)
  h.assert_true(
    notifications[1] and notifications[1]:find('render exploded', 1, true) ~= nil,
    'workspace autocmd rerender error was not notified',
    scope
  )

  local debounce_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(debounce_buf, 0, -1, false, { 'debounced name', 'debounced color', '' })
  local debounced_callback
  local original_defer_fn = vim.defer_fn
  vim.defer_fn = function(callback)
    debounced_callback = callback
    return {
      stop = function() end,
      close = function() end,
    }
  end
  config.setup({
    search = {
      debounce_ms = 10,
    },
  })
  local debounced_rerenders = 0
  local debounced_instance = {
    group_name = 'HlcraftUiAutocmdsDebounced' .. tostring(debounce_buf),
    ns = instance.ns,
    input_ns = instance.input_ns,
    state = {
      buf = debounce_buf,
      extmark_ids = {},
      geometry = ui_state.geometry(),
      name_query = '',
      color_query = '',
    },
    rerender = function()
      debounced_rerenders = debounced_rerenders + 1
    end,
    cleanup = function() end,
  }
  debounced_instance.state.geometry.inputs = vim.deepcopy(instance.state.geometry.inputs)
  set_input_marks(debounced_instance, 'name', 0, 1)
  set_input_marks(debounced_instance, 'color', 1, 2)
  autocmds.setup(debounced_instance)
  debounced_instance.state.rendering = true
  vim.api.nvim_exec_autocmds('TextChanged', {
    group = debounced_instance.group,
    buffer = debounce_buf,
    modeline = false,
  })
  debounced_instance.state.rendering = false
  h.assert_true(debounced_callback == nil, 'rendering debounced TextChanged scheduled a callback', scope)
  h.assert_true(debounced_instance.state.debounce_timer == nil, 'rendering debounced TextChanged kept a timer', scope)
  vim.api.nvim_exec_autocmds('TextChanged', {
    group = debounced_instance.group,
    buffer = debounce_buf,
    modeline = false,
  })
  vim.defer_fn = original_defer_fn
  h.assert_true(type(debounced_callback) == 'function', 'debounced TextChanged did not schedule callback', scope)
  vim.api.nvim_buf_delete(debounce_buf, { force = true })
  local stale_debounce_ok = pcall(debounced_callback)
  h.assert_true(stale_debounce_ok, 'stale debounced TextChanged escaped callback', scope)
  h.assert_true(debounced_instance.state.debounce_timer == nil, 'stale debounced TextChanged kept timer state', scope)
  h.assert_equal(debounced_rerenders, 0, 'stale debounced TextChanged rerendered invalid buffer', scope)
  vim.api.nvim_del_augroup_by_id(debounced_instance.group)

  local rendering_callback_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(rendering_callback_buf, 0, -1, false, { 'rendered name', 'rendered color', '' })
  local rendering_callback
  vim.defer_fn = function(callback)
    rendering_callback = callback
    return {
      stop = function() end,
      close = function() end,
    }
  end
  local rendering_callback_rerenders = 0
  local rendering_callback_instance = {
    group_name = 'HlcraftUiAutocmdsRenderingDebounceCallback' .. tostring(rendering_callback_buf),
    ns = instance.ns,
    input_ns = instance.input_ns,
    state = {
      buf = rendering_callback_buf,
      color_query = 'old color',
      extmark_ids = {},
      geometry = ui_state.geometry(),
      name_query = 'old name',
    },
    rerender = function()
      rendering_callback_rerenders = rendering_callback_rerenders + 1
    end,
    cleanup = function() end,
  }
  rendering_callback_instance.state.geometry.inputs = vim.deepcopy(instance.state.geometry.inputs)
  set_input_marks(rendering_callback_instance, 'name', 0, 1)
  set_input_marks(rendering_callback_instance, 'color', 1, 2)
  autocmds.setup(rendering_callback_instance)
  vim.api.nvim_exec_autocmds('TextChanged', {
    group = rendering_callback_instance.group,
    buffer = rendering_callback_buf,
    modeline = false,
  })
  h.assert_true(type(rendering_callback) == 'function', 'rendering callback debounce did not schedule', scope)
  local first_rendering_callback = rendering_callback
  rendering_callback = nil
  rendering_callback_instance.state.rendering = true
  first_rendering_callback()
  h.assert_equal(rendering_callback_rerenders, 0, 'rendering debounced callback rerendered during render', scope)
  h.assert_equal(
    rendering_callback_instance.state.name_query,
    'old name',
    'rendering debounced callback synced during render',
    scope
  )
  h.assert_true(
    type(rendering_callback) == 'function',
    'rendering debounced callback did not reschedule pending sync',
    scope
  )
  rendering_callback_instance.state.rendering = false
  rendering_callback()
  vim.defer_fn = original_defer_fn
  h.assert_equal(
    rendering_callback_instance.state.name_query,
    'rendered name',
    'rescheduled debounced callback did not sync after rendering',
    scope
  )
  h.assert_equal(
    rendering_callback_instance.state.color_query,
    'rendered color',
    'rescheduled debounced callback did not sync color after rendering',
    scope
  )
  h.assert_equal(rendering_callback_rerenders, 1, 'rescheduled debounced callback did not rerender once', scope)
  vim.api.nvim_del_augroup_by_id(rendering_callback_instance.group)
  vim.api.nvim_buf_delete(rendering_callback_buf, { force = true })

  local failed_reschedule_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(failed_reschedule_buf, 0, -1, false, { 'failed name', 'failed color', '' })
  local failed_reschedule_callback
  local failed_reschedule_timer = {
    stop = function() end,
    close = function() end,
  }
  local failed_reschedule_calls = 0
  vim.defer_fn = function(callback)
    failed_reschedule_calls = failed_reschedule_calls + 1
    if failed_reschedule_calls == 1 then
      failed_reschedule_callback = callback
      return failed_reschedule_timer
    end
    error('debounce reschedule failed')
  end
  local failed_reschedule_instance = {
    group_name = 'HlcraftUiAutocmdsFailedDebounceReschedule' .. tostring(failed_reschedule_buf),
    ns = instance.ns,
    input_ns = instance.input_ns,
    state = {
      buf = failed_reschedule_buf,
      color_query = 'old color',
      extmark_ids = {},
      geometry = ui_state.geometry(),
      name_query = 'old name',
    },
    rerender = function() end,
    cleanup = function() end,
  }
  failed_reschedule_instance.state.geometry.inputs = vim.deepcopy(instance.state.geometry.inputs)
  set_input_marks(failed_reschedule_instance, 'name', 0, 1)
  set_input_marks(failed_reschedule_instance, 'color', 1, 2)
  autocmds.setup(failed_reschedule_instance)
  vim.api.nvim_exec_autocmds('TextChanged', {
    group = failed_reschedule_instance.group,
    buffer = failed_reschedule_buf,
    modeline = false,
  })
  h.assert_true(type(failed_reschedule_callback) == 'function', 'failed reschedule debounce did not schedule', scope)
  failed_reschedule_instance.state.rendering = true
  local failed_reschedule_notifications = {}
  local failed_reschedule_ok = h.with_notify_stub(function()
    return pcall(failed_reschedule_callback)
  end, function(message)
    failed_reschedule_notifications[#failed_reschedule_notifications + 1] = message
  end)
  vim.defer_fn = original_defer_fn
  local failed_reschedule_timer_state = failed_reschedule_instance.state.debounce_timer
  vim.api.nvim_del_augroup_by_id(failed_reschedule_instance.group)
  vim.api.nvim_buf_delete(failed_reschedule_buf, { force = true })

  h.assert_true(failed_reschedule_ok, 'failed debounce reschedule escaped callback', scope)
  h.assert_true(failed_reschedule_timer_state == nil, 'failed debounce reschedule kept stale timer state', scope)
  h.assert_true(
    failed_reschedule_notifications[1]
      and failed_reschedule_notifications[1]:find('debounce reschedule failed', 1, true) ~= nil,
    'failed debounce reschedule was not notified',
    scope
  )

  local replaced_buf = vim.api.nvim_create_buf(false, true)
  local replacement_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(replaced_buf, 0, -1, false, { 'old name', 'old color', '' })
  vim.api.nvim_buf_set_lines(replacement_buf, 0, -1, false, { 'new name', 'new color', '' })
  local replaced_callback
  vim.defer_fn = function(callback)
    replaced_callback = callback
    return {
      stop = function() end,
      close = function() end,
    }
  end
  local replaced_rerenders = 0
  local replaced_instance = {
    group_name = 'HlcraftUiAutocmdsReplacedDebounce' .. tostring(replaced_buf),
    ns = instance.ns,
    input_ns = instance.input_ns,
    state = {
      buf = replaced_buf,
      color_query = 'before color',
      extmark_ids = {},
      geometry = ui_state.geometry(),
      name_query = 'before name',
    },
    rerender = function()
      replaced_rerenders = replaced_rerenders + 1
    end,
    cleanup = function() end,
  }
  replaced_instance.state.geometry.inputs = vim.deepcopy(instance.state.geometry.inputs)
  set_input_marks(replaced_instance, 'name', 0, 1)
  set_input_marks(replaced_instance, 'color', 1, 2)
  autocmds.setup(replaced_instance)
  vim.api.nvim_exec_autocmds('TextChanged', {
    group = replaced_instance.group,
    buffer = replaced_buf,
    modeline = false,
  })
  vim.defer_fn = original_defer_fn
  h.assert_true(type(replaced_callback) == 'function', 'replaced debounce did not schedule callback', scope)
  replaced_instance.state.buf = replacement_buf
  replaced_instance.state.extmark_ids = {}
  set_input_marks(replaced_instance, 'name', 0, 1)
  set_input_marks(replaced_instance, 'color', 1, 2)
  local replaced_debounce_ok = pcall(replaced_callback)
  h.assert_true(replaced_debounce_ok, 'replaced-buffer debounced TextChanged escaped callback', scope)
  h.assert_true(replaced_instance.state.debounce_timer == nil, 'replaced-buffer debounce kept timer state', scope)
  h.assert_equal(replaced_instance.state.name_query, 'before name', 'replaced-buffer debounce synced name query', scope)
  h.assert_equal(
    replaced_instance.state.color_query,
    'before color',
    'replaced-buffer debounce synced color query',
    scope
  )
  h.assert_equal(replaced_rerenders, 0, 'replaced-buffer debounce rerendered replacement buffer', scope)
  vim.api.nvim_del_augroup_by_id(replaced_instance.group)
  vim.api.nvim_buf_delete(replaced_buf, { force = true })
  vim.api.nvim_buf_delete(replacement_buf, { force = true })

  local superseded_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(superseded_buf, 0, -1, false, { 'superseded name', 'superseded color', '' })
  local superseded_callback
  local superseded_timer = {
    stop = function() end,
    close = function() end,
  }
  vim.defer_fn = function(callback)
    superseded_callback = callback
    return superseded_timer
  end
  local superseded_rerenders = 0
  local superseded_instance = {
    group_name = 'HlcraftUiAutocmdsSupersededDebounce' .. tostring(superseded_buf),
    ns = instance.ns,
    input_ns = instance.input_ns,
    state = {
      buf = superseded_buf,
      color_query = 'old color',
      extmark_ids = {},
      geometry = ui_state.geometry(),
      name_query = 'old name',
    },
    rerender = function()
      superseded_rerenders = superseded_rerenders + 1
    end,
    cleanup = function() end,
  }
  superseded_instance.state.geometry.inputs = vim.deepcopy(instance.state.geometry.inputs)
  set_input_marks(superseded_instance, 'name', 0, 1)
  set_input_marks(superseded_instance, 'color', 1, 2)
  autocmds.setup(superseded_instance)
  vim.api.nvim_exec_autocmds('TextChanged', {
    group = superseded_instance.group,
    buffer = superseded_buf,
    modeline = false,
  })
  vim.defer_fn = original_defer_fn
  h.assert_true(type(superseded_callback) == 'function', 'superseded debounce did not schedule callback', scope)
  local next_debounce_timer = {
    stop = function() end,
    close = function() end,
  }
  superseded_instance.state.debounce_timer = next_debounce_timer
  local superseded_debounce_ok = pcall(superseded_callback)
  h.assert_true(superseded_debounce_ok, 'superseded debounced TextChanged escaped callback', scope)
  h.assert_equal(
    superseded_instance.state.debounce_timer,
    next_debounce_timer,
    'superseded debounce cleared the newer timer',
    scope
  )
  h.assert_equal(superseded_instance.state.name_query, 'old name', 'superseded debounce synced name query', scope)
  h.assert_equal(superseded_instance.state.color_query, 'old color', 'superseded debounce synced color query', scope)
  h.assert_equal(superseded_rerenders, 0, 'superseded debounce rerendered', scope)
  vim.api.nvim_del_augroup_by_id(superseded_instance.group)
  vim.api.nvim_buf_delete(superseded_buf, { force = true })

  local detail_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(detail_buf, 0, -1, false, { 'late name', 'late color', '' })
  local detail_callback
  vim.defer_fn = function(callback)
    detail_callback = callback
    return {
      stop = function() end,
      close = function() end,
    }
  end
  local detail_rerenders = 0
  local detail_instance = {
    group_name = 'HlcraftUiAutocmdsDebouncedDetail' .. tostring(detail_buf),
    ns = instance.ns,
    input_ns = instance.input_ns,
    state = {
      buf = detail_buf,
      color_query = 'old color',
      detail_index = nil,
      extmark_ids = {},
      geometry = ui_state.geometry(),
      name_query = 'old name',
    },
    rerender = function()
      detail_rerenders = detail_rerenders + 1
    end,
    cleanup = function() end,
  }
  detail_instance.state.geometry.inputs = vim.deepcopy(instance.state.geometry.inputs)
  set_input_marks(detail_instance, 'name', 0, 1)
  set_input_marks(detail_instance, 'color', 1, 2)
  autocmds.setup(detail_instance)
  vim.api.nvim_exec_autocmds('TextChanged', {
    group = detail_instance.group,
    buffer = detail_buf,
    modeline = false,
  })
  vim.defer_fn = original_defer_fn
  h.assert_true(type(detail_callback) == 'function', 'detail debounce did not schedule callback', scope)
  detail_instance.state.detail_index = 1
  local detail_debounce_ok = pcall(detail_callback)
  h.assert_true(detail_debounce_ok, 'detail-entered debounced TextChanged escaped callback', scope)
  h.assert_true(detail_instance.state.debounce_timer == nil, 'detail-entered debounce kept timer state', scope)
  h.assert_equal(detail_instance.state.name_query, 'old name', 'detail-entered debounce synced name query', scope)
  h.assert_equal(detail_instance.state.color_query, 'old color', 'detail-entered debounce synced color query', scope)
  h.assert_equal(detail_rerenders, 0, 'detail-entered debounce rerendered detail scene', scope)
  vim.api.nvim_del_augroup_by_id(detail_instance.group)
  vim.api.nvim_buf_delete(detail_buf, { force = true })

  vim.api.nvim_del_augroup_by_id(throwing_instance.group)
  vim.api.nvim_del_augroup_by_id(instance.group)
  config.setup({})
end)

print('hlcraft ui autocmds: OK')
