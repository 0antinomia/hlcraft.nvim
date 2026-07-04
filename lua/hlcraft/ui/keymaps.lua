local actions = require('hlcraft.ui.actions')
local context = require('hlcraft.ui.context')
local buffer_fields = require('hlcraft.ui.input.buffer_fields')
local navigation = require('hlcraft.ui.navigation')
local scene = require('hlcraft.ui.scene')
local search_scene = require('hlcraft.ui.scene.search')
local ui_fields = require('hlcraft.ui.fields')
local lifecycle = require('hlcraft.ui.workspace.lifecycle')
local window = require('hlcraft.ui.workspace.window')

local M = {}

--- Set up insert and normal mode keymaps that protect input field boundaries
--- @param instance table The Instance object holding UI state
--- @param buf number Buffer handle to attach keymaps to
--- @return nil
local function setup_input_boundary_keys(instance, buf)
  local function setup_deletion(key, should_block)
    vim.keymap.set('i', key, function()
      if should_block(instance) then
        return
      end
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(key, true, false, true), 'n', false)
    end, { buffer = buf, silent = true })
  end

  setup_deletion('<BS>', buffer_fields.should_block_backward_delete)
  setup_deletion('<C-h>', buffer_fields.should_block_backward_delete)
  setup_deletion('<C-w>', buffer_fields.should_block_backward_delete)
  setup_deletion('<C-u>', buffer_fields.should_block_backward_delete)
  setup_deletion('<Del>', buffer_fields.should_block_forward_delete)

  for _, lhs in ipairs({ 'X', 'S', 'D', 'c', 'C' }) do
    vim.keymap.set('n', lhs, function()
      local win = window.get_win(instance)
      if not window.is_valid_win(win) then
        return
      end
      if search_scene.is_on_row(instance) then
        return
      end
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), 'n', false)
    end, { buffer = buf, silent = true, nowait = true })
  end

  for _, lhs in ipairs({ 'I', 'A', 'O' }) do
    vim.keymap.set('n', lhs, function()
      if search_scene.is_on_row(instance) then
        return
      end
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), 'n', false)
    end, { buffer = buf, silent = true, nowait = true })
  end
end

--- Set up all workspace keymaps for navigation, search, detail editing, and input cycling
--- @param instance table The Instance object holding UI state
--- @param buf number Buffer handle to attach keymaps to
--- @return nil
function M.setup_workspace_keymaps(instance, buf)
  local opts = { buffer = buf, silent = true, nowait = true }

  local function feed_normal_key(lhs)
    local win = window.get_win(instance)
    if not window.is_valid_win(win) then
      return
    end
    if search_scene.is_on_row(instance) then
      return
    end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), 'n', false)
  end

  local function run_action(action, ...)
    local ok = actions.dispatch(instance, action, ...)
    return ok
  end

  local function run_search_action(action)
    if scene.current_name(instance) == 'search' then
      actions.dispatch(instance, action)
    end
  end

  local function toggle_dynamic_color()
    if context.current_field_kind(instance) ~= 'color' then
      return
    end
    run_action('toggle_dynamic')
  end

  local function cycle_dynamic_preset(fallback_key)
    if not context.color_field_is_dynamic(instance) then
      if fallback_key then
        feed_normal_key(fallback_key)
      end
      return
    end
    run_action('cycle_dynamic_preset')
  end

  local function adjust_dynamic_color(delta)
    if not context.color_field_is_dynamic(instance) then
      return false
    end

    if context.current_dynamic_editor_row_key(instance) == 'dynamic_phase' then
      local dynamic = context.current_color_dynamic(instance)
      run_action('set_dynamic_phase', (tonumber(dynamic.phase) or 0) + (delta * ui_fields.dynamic_phase_step))
    else
      run_action('adjust_dynamic_duration', delta * ui_fields.dynamic_duration_step)
    end
    return true
  end

  local function adjust_color(channel, delta, fallback_key)
    if context.color_field_is_dynamic(instance) then
      return
    end
    if context.current_field_kind(instance) == 'color' then
      run_action('adjust_color', channel, delta)
      return
    end
    if fallback_key then
      feed_normal_key(fallback_key)
    end
  end

  local function set_color(value, fallback_key)
    if context.current_field_kind(instance) ~= 'color' then
      if fallback_key then
        feed_normal_key(fallback_key)
      end
      return
    end
    run_action('set_color', value)
  end

  local function adjust_blend(delta, fallback_key)
    if context.current_field_kind(instance) ~= 'blend' then
      if fallback_key then
        feed_normal_key(fallback_key)
      end
      return
    end
    run_action('adjust_blend', delta)
  end

  local function unset_blend(fallback_key)
    if context.current_field_kind(instance) ~= 'blend' then
      if fallback_key then
        feed_normal_key(fallback_key)
      end
      return
    end
    run_action('set_blend', nil)
  end

  local function input_current_editor_field()
    local kind = context.current_field_kind(instance)
    if not kind then
      return false
    end
    local field = instance.state.field_editor and instance.state.field_editor.field

    if kind == 'color' then
      if context.color_field_is_dynamic(instance) then
        run_action('input_dynamic_row', { default_raw = true })
        return true
      end
      vim.ui.input({ prompt = field .. ': ' }, function(value)
        if value == nil then
          return
        end
        set_color(value)
      end)
      return true
    end

    if kind == 'group' then
      vim.ui.input({ prompt = 'Group: ' }, function(value)
        if value == nil then
          return
        end
        run_action('set_group', value)
      end)
      return true
    end

    if kind == 'blend' then
      vim.ui.input({ prompt = 'Blend: ' }, function(value)
        if value == nil then
          return
        end
        run_action('set_blend', value)
      end)
      return true
    end

    return false
  end

  local function jump_to_input_at_cursor(insert)
    local win = window.get_win(instance)
    if not window.is_valid_win(win) then
      return false
    end
    local field = buffer_fields.get_field_at_row(instance, vim.api.nvim_win_get_cursor(win)[1] - 1)
    if not field then
      return false
    end
    navigation.jump_to_row(instance, field.line, insert)
    return true
  end

  vim.keymap.set('n', '<Esc>', function()
    actions.back(instance)
  end, opts)
  vim.keymap.set('n', 'q', function()
    actions.back(instance)
  end, opts)
  vim.keymap.set('n', '?', function()
    lifecycle.toggle_help(instance)
  end, opts)
  vim.keymap.set('n', 'j', function()
    navigation.move_interactive(instance, 1)
  end, opts)
  vim.keymap.set('n', 'k', function()
    navigation.move_interactive(instance, -1)
  end, opts)
  vim.keymap.set('n', '<Down>', function()
    navigation.move_interactive(instance, 1)
  end, opts)
  vim.keymap.set('n', '<Up>', function()
    navigation.move_interactive(instance, -1)
  end, opts)
  vim.keymap.set('n', 'gg', function()
    local rows = navigation.allowed_rows(instance)
    if #rows > 0 then
      navigation.jump_to_row(instance, rows[1], false)
    end
  end, opts)
  vim.keymap.set('n', 'G', function()
    if context.current_field_kind(instance) == 'color' then
      adjust_color('g', ui_fields.color_step)
      return
    end
    local rows = navigation.allowed_rows(instance)
    if #rows > 0 then
      navigation.jump_to_row(instance, rows[#rows], false)
    end
  end, opts)
  vim.keymap.set('n', '<Tab>', function()
    buffer_fields.goto_next(instance)
  end, opts)
  vim.keymap.set('n', '<S-Tab>', function()
    buffer_fields.goto_prev(instance)
  end, opts)
  vim.keymap.set('n', 'J', function()
    run_search_action('next_result')
  end, opts)
  vim.keymap.set('n', 'K', function()
    run_search_action('prev_result')
  end, opts)
  vim.keymap.set('n', 'gr', function()
    run_search_action('first_result')
  end, opts)
  vim.keymap.set('n', 'p', function()
    buffer_fields.paste_below(instance, false)
  end, opts)
  vim.keymap.set('x', 'p', function()
    buffer_fields.paste_below(instance, true)
  end, opts)
  vim.keymap.set('n', 'P', function()
    buffer_fields.paste_above(instance, false)
  end, opts)
  vim.keymap.set('x', 'P', function()
    buffer_fields.paste_above(instance, true)
  end, opts)
  vim.keymap.set('n', 'o', function()
    buffer_fields.open_below(instance)
  end, opts)
  vim.keymap.set('n', 's', function()
    if not instance.state.detail_index then
      feed_normal_key('s')
      return
    end
    actions.dispatch(instance, 'save')
  end, opts)
  vim.keymap.set('n', 'r', function()
    adjust_color('r', -ui_fields.color_step, 'r')
  end, opts)
  vim.keymap.set('n', 'R', function()
    adjust_color('r', ui_fields.color_step, 'R')
  end, opts)
  vim.keymap.set('n', 'g', function()
    if context.current_field_kind(instance) ~= 'color' then
      feed_normal_key('g')
      return
    end
    adjust_color('g', -ui_fields.color_step)
  end, vim.tbl_extend('force', opts, { nowait = false }))
  vim.keymap.set('n', 'b', function()
    adjust_color('b', -ui_fields.color_step, 'b')
  end, opts)
  vim.keymap.set('n', 'B', function()
    adjust_color('b', ui_fields.color_step, 'B')
  end, opts)
  vim.keymap.set('n', 'n', function()
    set_color('NONE', 'n')
  end, opts)
  vim.keymap.set('n', 'd', function()
    toggle_dynamic_color()
  end, opts)
  vim.keymap.set('n', 'm', function()
    cycle_dynamic_preset('m')
  end, opts)
  vim.keymap.set('n', '[', function()
    feed_normal_key('[')
  end, opts)
  vim.keymap.set('n', ']', function()
    feed_normal_key(']')
  end, opts)
  vim.keymap.set('n', '+', function()
    if adjust_dynamic_color(1) then
      return
    end
    adjust_blend(ui_fields.blend_small_step, '+')
  end, opts)
  vim.keymap.set('n', '-', function()
    if adjust_dynamic_color(-1) then
      return
    end
    adjust_blend(-ui_fields.blend_small_step, '-')
  end, opts)
  vim.keymap.set('n', '>', function()
    adjust_blend(ui_fields.blend_large_step, '>')
  end, opts)
  vim.keymap.set('n', '<', function()
    adjust_blend(-ui_fields.blend_large_step, '<')
  end, opts)
  vim.keymap.set('n', 'u', function()
    unset_blend('u')
  end, opts)
  vim.keymap.set('n', 'i', function()
    if input_current_editor_field() then
      return
    end
    jump_to_input_at_cursor(true)
  end, opts)
  vim.keymap.set('n', 'e', function()
    if context.color_field_is_dynamic(instance) then
      run_action('open_dynamic_raw_json')
      return
    end
    feed_normal_key('e')
  end, opts)
  vim.keymap.set('n', 'x', function()
    feed_normal_key('x')
  end, opts)
  vim.keymap.set('n', 'a', function()
    if jump_to_input_at_cursor(true) then
      return
    end
    feed_normal_key('a')
  end, opts)

  vim.keymap.set({ 'n', 'i' }, '<CR>', function()
    vim.schedule(function()
      actions.dispatch(instance, 'activate')
    end)
    return ''
  end, vim.tbl_extend('force', opts, { expr = true }))

  setup_input_boundary_keys(instance, buf)
end

return M
