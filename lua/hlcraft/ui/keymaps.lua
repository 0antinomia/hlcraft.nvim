local input_actions = require('hlcraft.ui.input.actions')
local input_model = require('hlcraft.ui.input.model')
local navigation = require('hlcraft.ui.navigation')
local detail_values = require('hlcraft.ui.state.detail_values')
local results_state = require('hlcraft.ui.state.results')
local field_editor = require('hlcraft.ui.state.field_editor')
local ui_fields = require('hlcraft.ui.fields')
local workspace = require('hlcraft.ui.workspace')

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

  setup_deletion('<BS>', input_actions.should_block_backward_delete)
  setup_deletion('<C-h>', input_actions.should_block_backward_delete)
  setup_deletion('<C-w>', input_actions.should_block_backward_delete)
  setup_deletion('<C-u>', input_actions.should_block_backward_delete)
  setup_deletion('<Del>', input_actions.should_block_forward_delete)

  for _, lhs in ipairs({ 'x', 'X', 'S', 'D', 'c', 'C' }) do
    vim.keymap.set('n', lhs, function()
      local win = workspace.get_win(instance)
      if not workspace.is_valid_win(win) then
        return
      end
      if results_state.is_on_row(instance) then
        return
      end
      vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), 'n', false)
    end, { buffer = buf, silent = true, nowait = true })
  end

  for _, lhs in ipairs({ 'I', 'A', 'O' }) do
    vim.keymap.set('n', lhs, function()
      if results_state.is_on_row(instance) then
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
    local win = workspace.get_win(instance)
    if not workspace.is_valid_win(win) then
      return
    end
    if results_state.is_on_row(instance) then
      return
    end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), 'n', false)
  end

  local function close_or_quit()
    if instance.state.field_editor and instance.state.field_editor.field then
      field_editor.close(instance)
      return
    end
    instance:quit_or_back()
  end

  local function notify_error(err)
    if err then
      vim.notify(('hlcraft: %s'):format(err), vim.log.levels.ERROR)
    end
  end

  local function current_field_kind()
    local field = instance.state.field_editor and instance.state.field_editor.field
    if not field then
      return nil
    end
    return ui_fields.detail_kinds[field]
  end

  local function current_color_field_is_dynamic()
    local field = instance.state.field_editor and instance.state.field_editor.field
    local result = results_state.current_detail_result(instance)
    return current_field_kind() == 'color' and result ~= nil and detail_values.dynamic_value(result.name, field) ~= nil
  end

  local function toggle_dynamic_color()
    if current_field_kind() ~= 'color' then
      return
    end
    local ok, err = field_editor.toggle_dynamic(instance)
    if not ok then
      notify_error(err)
    end
  end

  local function cycle_dynamic_mode(fallback_key)
    if not current_color_field_is_dynamic() then
      if fallback_key then
        feed_normal_key(fallback_key)
      end
      return
    end
    local ok, err = field_editor.cycle_dynamic_mode(instance)
    if not ok then
      notify_error(err)
    end
  end

  local function adjust_color(channel, delta, fallback_key)
    if current_color_field_is_dynamic() then
      return
    end
    if current_field_kind() == 'color' then
      local ok, err = field_editor.adjust_color(instance, channel, delta)
      if not ok then
        notify_error(err)
      end
      return
    end
    if fallback_key then
      feed_normal_key(fallback_key)
    end
  end

  local function set_color(value, fallback_key)
    if current_field_kind() ~= 'color' then
      if fallback_key then
        feed_normal_key(fallback_key)
      end
      return
    end
    local ok, err = field_editor.set_color(instance, value)
    if not ok then
      notify_error(err)
    end
  end

  local function adjust_blend(delta, fallback_key)
    if current_field_kind() ~= 'blend' then
      if fallback_key then
        feed_normal_key(fallback_key)
      end
      return
    end
    local ok, err = field_editor.adjust_blend(instance, delta)
    if not ok then
      notify_error(err)
    end
  end

  local function unset_blend(fallback_key)
    if current_field_kind() ~= 'blend' then
      if fallback_key then
        feed_normal_key(fallback_key)
      end
      return
    end
    local ok, err = field_editor.set_blend(instance, nil)
    if not ok then
      notify_error(err)
    end
  end

  local function input_current_editor_field()
    local field = instance.state.field_editor and instance.state.field_editor.field
    if not field then
      return false
    end

    local kind = ui_fields.detail_kinds[field]
    if kind == 'color' then
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
        local ok, err = field_editor.set_group(instance, value)
        if not ok then
          notify_error(err)
        end
      end)
      return true
    end

    if kind == 'blend' then
      vim.ui.input({ prompt = 'Blend: ' }, function(value)
        if value == nil then
          return
        end
        local ok, err = field_editor.set_blend(instance, value)
        if not ok then
          notify_error(err)
        end
      end)
      return true
    end

    return false
  end

  vim.keymap.set('n', '<Esc>', function()
    close_or_quit()
  end, opts)
  vim.keymap.set('n', 'q', function()
    close_or_quit()
  end, opts)
  vim.keymap.set('n', '?', function()
    workspace.toggle_help(instance)
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
    if current_field_kind() == 'color' then
      adjust_color('g', ui_fields.color_step)
      return
    end
    local rows = navigation.allowed_rows(instance)
    if #rows > 0 then
      navigation.jump_to_row(instance, rows[#rows], false)
    end
  end, opts)
  vim.keymap.set('n', '<Tab>', function()
    input_actions.goto_next_input(instance)
  end, opts)
  vim.keymap.set('n', '<S-Tab>', function()
    input_actions.goto_prev_input(instance)
  end, opts)
  vim.keymap.set('n', 'J', function()
    results_state.goto_offset(instance, 1)
  end, opts)
  vim.keymap.set('n', 'K', function()
    results_state.goto_offset(instance, -1)
  end, opts)
  vim.keymap.set('n', 'gr', function()
    results_state.goto_first(instance)
  end, opts)
  vim.keymap.set('n', 'p', function()
    input_actions.paste_below(instance, false)
  end, opts)
  vim.keymap.set('x', 'p', function()
    input_actions.paste_below(instance, true)
  end, opts)
  vim.keymap.set('n', 'P', function()
    input_actions.paste_above(instance, false)
  end, opts)
  vim.keymap.set('x', 'P', function()
    input_actions.paste_above(instance, true)
  end, opts)
  vim.keymap.set('n', 'o', function()
    input_actions.open_below(instance)
  end, opts)
  vim.keymap.set('n', 's', function()
    local result = results_state.current_detail_result(instance)
    if not result then
      feed_normal_key('s')
      return
    end
    local ok, err = detail_values.save(instance, result.name)
    if not ok then
      notify_error(err or 'Failed to save highlight override')
    end
  end, opts)
  vim.keymap.set('n', 'r', function()
    adjust_color('r', -ui_fields.color_step, 'r')
  end, opts)
  vim.keymap.set('n', 'R', function()
    adjust_color('r', ui_fields.color_step, 'R')
  end, opts)
  vim.keymap.set('n', 'g', function()
    if current_field_kind() ~= 'color' then
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
    cycle_dynamic_mode('m')
  end, opts)
  vim.keymap.set('n', '+', function()
    if current_color_field_is_dynamic() then
      local ok, err = field_editor.adjust_dynamic_speed(instance, ui_fields.dynamic_speed_step)
      if not ok then
        notify_error(err)
      end
      return
    end
    adjust_blend(ui_fields.blend_small_step, '+')
  end, opts)
  vim.keymap.set('n', '-', function()
    if current_color_field_is_dynamic() then
      local ok, err = field_editor.adjust_dynamic_speed(instance, -ui_fields.dynamic_speed_step)
      if not ok then
        notify_error(err)
      end
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
    local win = workspace.get_win(instance)
    if not workspace.is_valid_win(win) then
      return
    end
    local field = input_model.get_input_field_at_row(instance, vim.api.nvim_win_get_cursor(win)[1] - 1)
    if field then
      navigation.jump_to_row(instance, field.line, true)
    end
  end, opts)
  vim.keymap.set('n', 'a', function()
    local win = workspace.get_win(instance)
    if not workspace.is_valid_win(win) then
      return
    end
    local field = input_model.get_input_field_at_row(instance, vim.api.nvim_win_get_cursor(win)[1] - 1)
    if field then
      navigation.jump_to_row(instance, field.line, true)
    end
  end, opts)

  vim.keymap.set({ 'n', 'i' }, '<CR>', function()
    vim.schedule(function()
      local win = workspace.get_win(instance)
      local row = workspace.is_valid_win(win) and vim.api.nvim_win_get_cursor(win)[1] or 0
      local area = input_model.current_area(instance, row)
      if instance.state.detail_index then
        field_editor.activate(instance)
      elseif area == 'results' then
        results_state.open_detail(instance)
      else
        if vim.fn.mode():lower():find('i') then
          vim.cmd('stopinsert')
        end
        input_model.sync_queries_from_buffer(instance)
        instance:rerender()
        if #instance.state.results > 0 then
          local target_line = nil
          for _, entry in ipairs(results_state.rows(instance)) do
            if entry.index == instance.state.list_cursor then
              target_line = entry.line
              break
            end
          end
          if target_line then
            navigation.jump_to_row(instance, target_line, false)
          else
            results_state.goto_first(instance)
          end
        end
      end
    end)
    return ''
  end, vim.tbl_extend('force', opts, { expr = true }))

  setup_input_boundary_keys(instance, buf)
end

return M
