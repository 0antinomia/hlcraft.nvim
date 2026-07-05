local h = require('tests.helpers')
local scope = 'hlcraft highlight names'

local highlight_names = require('hlcraft.core.highlight_names')

h.assert_equal(highlight_names.assert('Normal'), 'Normal', 'valid highlight name was changed', scope)

local nil_name_ok = pcall(highlight_names.assert, nil)
h.assert_true(not nil_name_ok, 'highlight name helper accepted nil', scope)
local empty_name_ok = pcall(highlight_names.assert, '')
h.assert_true(not empty_name_ok, 'highlight name helper accepted empty text', scope)
local blank_name_ok = pcall(highlight_names.assert, '   ')
h.assert_true(not blank_name_ok, 'highlight name helper accepted blank text', scope)
local spaced_name_ok = pcall(highlight_names.assert, 'Bad Name')
h.assert_true(not spaced_name_ok, 'highlight name helper accepted whitespace', scope)
local command_name_ok = pcall(highlight_names.assert, 'Bad|Name')
h.assert_true(not command_name_ok, 'highlight name helper accepted command separators', scope)

print('hlcraft highlight names: OK')
