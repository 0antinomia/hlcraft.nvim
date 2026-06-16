local input_actions = require('hlcraft.ui.input.actions')
local input_model = require('hlcraft.ui.input.model')
local navigation = require('hlcraft.ui.navigation')
local session = require('hlcraft.ui.session')
local scene = require('hlcraft.ui.scene')
local search_scene = require('hlcraft.ui.scene.search')
local results_state = require('hlcraft.ui.state.results')
local detail_commands = require('hlcraft.ui.commands.detail')
local editor = require('hlcraft.ui.commands.editor')
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

  setup_deletion('<BS>', input_actions.should_block_backward_delete)
  setup_deletion('<C-h>', input_actions.should_block_backward_delete)
  setup_deletion('<C-w>', input_actions.should_block_backward_delete)
  setup_deletion('<C-u>', input_actions.should_block_backward_delete)
  setup_deletion('<Del>', input_actions.should_block_forward_delete)

  for _, lhs in ipairs({ 'X', 'S', 'D', 'c', 'C' }) do
    vim.keymap.set('n', lhs, function()
      local win = window.get_win(instance)
      if not window.is_valid_win(win) then
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
    local win = window.get_win(instance)
    if not window.is_valid_win(win) then
      return
    end
    if results_state.is_on_row(instance) then
      return
    end
    vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(lhs, true, false, true), 'n', false)
  end

  local function notify_error(err)
    if err then
      vim.notify(('hlcraft: %s'):format(err), vim.log.levels.ERROR)
    end
  end

  local function run_editor(command, ...)
    local ok, err = command(instance, ...)
    if not ok then
      notify_error(err)
    end
    return ok
  end

  local function editor_scene_is_active()
    local current_scene = scene.current_name(instance)
    return instance.state.detail_index ~= nil and (current_scene == 'detail' or current_scene == 'field_editor')
  end

  local function current_field_kind()
    if not editor_scene_is_active() then
      return nil
    end
    local field = instance.state.field_editor and instance.state.field_editor.field
    if not field then
      return nil
    end
    return ui_fields.detail_kinds[field]
  end

  local function current_color_dynamic()
    local field = instance.state.field_editor and instance.state.field_editor.field
    local result = results_state.current_detail_result(instance)
    if current_field_kind() ~= 'color' or not result then
      return nil
    end
    return session.dynamic_value(result.name, field)
  end

  local function current_color_field_is_dynamic()
    return current_color_dynamic() ~= nil
  end

  local function current_color_field_is_rgb_dynamic()
    local dynamic = current_color_dynamic()
    return dynamic ~= nil and dynamic.mode == 'rgb'
  end

  local function current_color_field_is_breath_dynamic()
    local dynamic = current_color_dynamic()
    return dynamic ~= nil and dynamic.mode == 'breath'
  end

  local function toggle_dynamic_color()
    if current_field_kind() ~= 'color' then
      return
    end
    run_editor(editor.toggle_dynamic)
  end

  local function cycle_dynamic_mode(fallback_key)
    if not current_color_field_is_dynamic() then
      if fallback_key then
        feed_normal_key(fallback_key)
      end
      return
    end
    run_editor(editor.cycle_dynamic_mode)
  end

  local function adjust_color(channel, delta, fallback_key)
    if current_color_field_is_dynamic() then
      return
    end
    if current_field_kind() == 'color' then
      run_editor(editor.adjust_color, channel, delta)
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
    run_editor(editor.set_color, value)
  end

  local function adjust_blend(delta, fallback_key)
    if current_field_kind() ~= 'blend' then
      if fallback_key then
        feed_normal_key(fallback_key)
      end
      return
    end
    run_editor(editor.adjust_blend, delta)
  end

  local function unset_blend(fallback_key)
    if current_field_kind() ~= 'blend' then
      if fallback_key then
        feed_normal_key(fallback_key)
      end
      return
    end
    run_editor(editor.set_blend, nil)
  end

  local function adjust_dynamic_param_or_speed(param_delta, speed_delta)
    local param_name = editor.selected_param_name(instance)
    if param_name then
      run_editor(editor.adjust_dynamic_param, param_name, param_delta)
      return
    end

    run_editor(editor.adjust_dynamic_speed, speed_delta)
  end

  local function input_current_editor_field()
    local kind = current_field_kind()
    if not kind then
      return false
    end
    local field = instance.state.field_editor and instance.state.field_editor.field

    if kind == 'color' then
      if current_color_field_is_rgb_dynamic() then
        vim.ui.input({ prompt = 'Palette color: ' }, function(value)
          if value == nil then
            return
          end
          run_editor(editor.set_dynamic_palette_color, value)
        end)
        return true
      end
      if current_color_field_is_breath_dynamic() then
        local param_name = editor.selected_param_name(instance) or 'min'
        vim.ui.input({ prompt = ('Breath %s: '):format(param_name) }, function(value)
          if value == nil then
            return
          end
          run_editor(editor.set_dynamic_param, param_name, value)
        end)
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
        run_editor(editor.set_group, value)
      end)
      return true
    end

    if kind == 'blend' then
      vim.ui.input({ prompt = 'Blend: ' }, function(value)
        if value == nil then
          return
        end
        run_editor(editor.set_blend, value)
      end)
      return true
    end

    return false
  end

  vim.keymap.set('n', '<Esc>', function()
    scene.back(instance)
  end, opts)
  vim.keymap.set('n', 'q', function()
    scene.back(instance)
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
    search_scene.goto_offset(instance, 1)
  end, opts)
  vim.keymap.set('n', 'K', function()
    search_scene.goto_offset(instance, -1)
  end, opts)
  vim.keymap.set('n', 'gr', function()
    search_scene.goto_first(instance)
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
    local ok, err = detail_commands.save_current(instance)
    if ok == false and err == nil then
      feed_normal_key('s')
      return
    end
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
  vim.keymap.set('n', '[', function()
    if not current_color_field_is_rgb_dynamic() then
      feed_normal_key('[')
      return
    end
    run_editor(editor.select_dynamic_palette, -1)
  end, opts)
  vim.keymap.set('n', ']', function()
    if not current_color_field_is_rgb_dynamic() then
      feed_normal_key(']')
      return
    end
    run_editor(editor.select_dynamic_palette, 1)
  end, opts)
  vim.keymap.set('n', '+', function()
    if current_color_field_is_dynamic() then
      adjust_dynamic_param_or_speed(ui_fields.dynamic_param_step, ui_fields.dynamic_speed_step)
      return
    end
    adjust_blend(ui_fields.blend_small_step, '+')
  end, opts)
  vim.keymap.set('n', '-', function()
    if current_color_field_is_dynamic() then
      adjust_dynamic_param_or_speed(-ui_fields.dynamic_param_step, -ui_fields.dynamic_speed_step)
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
    local win = window.get_win(instance)
    if not window.is_valid_win(win) then
      return
    end
    local field = input_model.get_input_field_at_row(instance, vim.api.nvim_win_get_cursor(win)[1] - 1)
    if field then
      navigation.jump_to_row(instance, field.line, true)
    end
  end, opts)
  vim.keymap.set('n', 'x', function()
    if current_color_field_is_rgb_dynamic() then
      run_editor(editor.delete_dynamic_palette_color)
      return
    end
    feed_normal_key('x')
  end, opts)
  vim.keymap.set('n', 'a', function()
    local win = window.get_win(instance)
    if not window.is_valid_win(win) then
      return
    end
    local field = input_model.get_input_field_at_row(instance, vim.api.nvim_win_get_cursor(win)[1] - 1)
    if field then
      navigation.jump_to_row(instance, field.line, true)
      return
    end
    if current_color_field_is_rgb_dynamic() then
      run_editor(editor.add_dynamic_palette_color)
    end
  end, opts)

  vim.keymap.set({ 'n', 'i' }, '<CR>', function()
    vim.schedule(function()
      local win = window.get_win(instance)
      local row = window.is_valid_win(win) and vim.api.nvim_win_get_cursor(win)[1] or 0
      local area = input_model.current_area(instance, row)
      if instance.state.detail_index then
        local ok, err = scene.handle(instance, 'activate')
        if not ok then
          notify_error(err)
        end
      elseif area == 'results' then
        search_scene.open_detail(instance)
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
            search_scene.goto_first(instance)
          end
        end
      end
    end)
    return ''
  end, vim.tbl_extend('force', opts, { expr = true }))

  setup_input_boundary_keys(instance, buf)
end

return M
