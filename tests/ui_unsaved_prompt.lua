local h = require('tests.helpers')
local scope = 'hlcraft ui unsaved prompt'

local prompt = require('hlcraft.ui.scene.unsaved_prompt')

local assert_fails = h.scoped_assert_fails(scope)

assert_fails(function()
  prompt.close(nil)
end, 'unsaved prompt close accepted missing instance')
local missing_prompt_state_ok = pcall(prompt.close, {
  state = {},
})
h.assert_true(not missing_prompt_state_ok, 'unsaved prompt accepted missing state schema', scope)
assert_fails(function()
  prompt.open({
    ns = false,
    state = {
      unsaved_prompt = {},
    },
  }, 'HlcraftUiUnsavedPrompt', function() end)
end, 'unsaved prompt accepted invalid namespace')
assert_fails(function()
  prompt.open({
    state = {
      unsaved_prompt = {},
    },
  }, '', function() end)
end, 'unsaved prompt accepted empty name')
local spaced_name_instance = {
  state = {
    unsaved_prompt = {},
  },
}
local spaced_name_ok = pcall(prompt.open, spaced_name_instance, 'Bad Name', function() end)
if spaced_name_ok then
  prompt.close(spaced_name_instance)
end
h.assert_true(not spaced_name_ok, 'unsaved prompt accepted whitespace in name', scope)
assert_fails(function()
  prompt.open({
    state = {
      unsaved_prompt = {},
    },
  }, 'HlcraftUiUnsavedPrompt', nil)
end, 'unsaved prompt accepted missing callback')

local instance = {
  ns = vim.api.nvim_create_namespace('hlcraft-ui-unsaved-prompt-test'),
  state = {
    unsaved_prompt = {},
  },
}

prompt.open(instance, 'HlcraftUiUnsavedPrompt', function() end)

local buf = instance.state.unsaved_prompt.buf
local win = instance.state.unsaved_prompt.win
h.assert_true(vim.api.nvim_buf_is_valid(buf), 'prompt buffer was not created', scope)
h.assert_true(vim.api.nvim_win_is_valid(win), 'prompt window was not created', scope)
h.assert_equal(
  table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), '\n'),
  table.concat(prompt.lines, '\n'),
  'prompt lines changed',
  scope
)
h.assert_true(vim.tbl_contains(prompt.lines, '[s] save draft'), 'prompt save keycap line missing', scope)
h.assert_true(vim.tbl_contains(prompt.lines, '[c/q/Esc] cancel'), 'prompt cancel keycap line missing', scope)

local mappings = {}
for _, item in ipairs(vim.api.nvim_buf_get_keymap(buf, 'n')) do
  mappings[item.lhs] = true
end
for _, lhs in ipairs({ 's', 'd', 'c', 'q', '<Esc>' }) do
  h.assert_true(mappings[lhs], ('missing prompt mapping %s'):format(lhs), scope)
end

local marks = vim.api.nvim_buf_get_extmarks(buf, instance.ns, 0, -1, { details = true })
h.assert_true(#marks > 0, 'prompt did not apply visual hierarchy highlights', scope)

prompt.close(instance)
h.assert_true(instance.state.unsaved_prompt.buf == nil, 'prompt buffer handle was not cleared', scope)
h.assert_true(instance.state.unsaved_prompt.win == nil, 'prompt window handle was not cleared', scope)
h.assert_true(not vim.api.nvim_buf_is_valid(buf), 'prompt buffer was not deleted', scope)

print('hlcraft ui unsaved prompt: OK')
