local h = require('tests.helpers')
local scope = 'hlcraft core source'

local source = require('hlcraft.core.source')

local valid_ok = pcall(source.get_source, 'Normal')
h.assert_true(valid_ok, 'source lookup rejected a valid group name', scope)

local nil_name_ok = pcall(source.get_source, nil)
h.assert_true(not nil_name_ok, 'source lookup accepted nil group name', scope)
local empty_name_ok = pcall(source.get_source, '')
h.assert_true(not empty_name_ok, 'source lookup accepted empty group name', scope)
local spaced_name_ok = pcall(source.get_source, 'Bad Name')
h.assert_true(not spaced_name_ok, 'source lookup accepted whitespace in group name', scope)

vim.g.hlcraft_source_injected = nil
local command_separator_ok = pcall(source.get_source, 'Normal | let g:hlcraft_source_injected = 1')
h.assert_true(not command_separator_ok, 'source lookup accepted command separators in group name', scope)
h.assert_true(vim.g.hlcraft_source_injected == nil, 'source lookup executed injected command text', scope)

print('hlcraft core source: OK')
