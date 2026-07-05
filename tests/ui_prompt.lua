local h = require('tests.helpers')
local scope = 'hlcraft ui prompt'

local prompt = require('hlcraft.ui.prompt')

local original_input = vim.ui.input
local prompts = {}
local submitted = {}

vim.ui.input = function(opts, callback)
  prompts[#prompts + 1] = opts
  callback(opts.value)
end

prompt.input({ prompt = 'Value: ', value = 'next' }, function(value)
  submitted[#submitted + 1] = value
  return true, nil
end)
h.assert_equal(prompts[1].prompt, 'Value: ', 'prompt options were not forwarded', scope)
h.assert_equal(submitted[1], 'next', 'prompt value was not submitted', scope)

prompt.input({ value = nil }, function()
  submitted[#submitted + 1] = 'cancelled'
end)
h.assert_equal(#submitted, 1, 'cancelled prompt submitted a value', scope)

local notifications = {}
h.with_notify_stub(function()
  prompt.input({ value = 'bad' }, function()
    return false, 'bad value'
  end)
end, function(message)
  notifications[#notifications + 1] = message
end)
h.assert_equal(notifications[1], 'hlcraft: bad value', 'prompt failure was not notified', scope)

h.with_notify_stub(function()
  prompt.input({ value = 'quiet' }, function()
    return false, 'quiet error'
  end, { notify_errors = false })
end, function(message)
  notifications[#notifications + 1] = message
end)
h.assert_equal(#notifications, 1, 'quiet prompt failure still notified', scope)

local invalid_input_opts_ok = pcall(prompt.input, nil, function() end)
h.assert_true(not invalid_input_opts_ok, 'prompt accepted missing vim input options', scope)
local invalid_submit_ok = pcall(prompt.input, {}, nil)
h.assert_true(not invalid_submit_ok, 'prompt accepted missing submit callback', scope)
local invalid_prompt_opts_ok = pcall(prompt.input, {}, function() end, false)
h.assert_true(not invalid_prompt_opts_ok, 'prompt accepted non-table options', scope)
local invalid_notify_opts_ok = pcall(prompt.input, {}, function() end, { notify_errors = 'no' })
h.assert_true(not invalid_notify_opts_ok, 'prompt accepted non-boolean notify_errors option', scope)
local invalid_value_ok = pcall(prompt.input, { value = false }, function()
  return true, nil
end)
h.assert_true(not invalid_value_ok, 'prompt accepted non-string input value', scope)
local invalid_submit_result_ok = pcall(prompt.input, { value = 'bad return' }, function() end)
h.assert_true(not invalid_submit_result_ok, 'prompt accepted non-boolean submit result', scope)

vim.ui.input = original_input

print('hlcraft ui prompt: OK')
