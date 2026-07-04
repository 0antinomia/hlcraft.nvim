local h = require('tests.helpers')
local scope = 'hlcraft engine patch'

local patch = require('hlcraft.engine.patch')

h.assert_true(patch.is_color_key('fg'), 'fg was not recognized as a color key', scope)
h.assert_true(patch.is_style_key('bold'), 'bold was not recognized as a style key', scope)
h.assert_true(patch.is_dynamic_key('sp'), 'sp was not recognized as a dynamic key', scope)
h.assert_true(not patch.is_color_key('bold'), 'style key was recognized as color key', scope)

local invalid_patch_ok, invalid_patch_err = patch.validate(false)
h.assert_true(not invalid_patch_ok, 'non-table patch was accepted', scope)
h.assert_equal(invalid_patch_err, 'Patch must be a table', 'non-table patch error changed', scope)

local invalid_key_ok, invalid_key_err = patch.validate({ unknown = true })
h.assert_true(not invalid_key_ok, 'unknown override key was accepted', scope)
h.assert_equal(invalid_key_err, 'Unsupported override key: unknown', 'unknown key error changed', scope)

local invalid_dynamic_type_ok, invalid_dynamic_type_err = patch.validate({ dynamic = 'fg' })
h.assert_true(not invalid_dynamic_type_ok, 'non-table dynamic patch was accepted', scope)
h.assert_equal(invalid_dynamic_type_err, 'dynamic patch must be a table', 'dynamic type error changed', scope)

local invalid_dynamic_ok, invalid_dynamic_err = patch.validate({ dynamic = { unknown = {} } })
h.assert_true(not invalid_dynamic_ok, 'unknown dynamic key was accepted', scope)
h.assert_equal(invalid_dynamic_err, 'Unsupported dynamic key: unknown', 'unknown dynamic key error changed', scope)

local invalid_group_type, invalid_group_type_err = patch.normalize({ group = 42 })
h.assert_true(invalid_group_type == nil, 'numeric group was normalized', scope)
h.assert_equal(invalid_group_type_err, 'Group name must be a string', 'group type error changed', scope)

local invalid_group_empty, invalid_group_empty_err = patch.normalize({ group = '  ' })
h.assert_true(invalid_group_empty == nil, 'empty group was normalized', scope)
h.assert_equal(invalid_group_empty_err, 'Group name is required', 'empty group error changed', scope)

local clear_group, clear_group_err = patch.normalize({ group = vim.NIL })
h.assert_true(clear_group ~= nil, clear_group_err or 'explicit group clear did not normalize', scope)
h.assert_equal(clear_group.group, vim.NIL, 'explicit group clear did not keep sentinel', scope)

local invalid_blend, invalid_blend_err = patch.normalize({ blend = 101 })
h.assert_true(invalid_blend == nil, 'out-of-range blend was normalized', scope)
h.assert_equal(invalid_blend_err, 'Blend override must be between 0 and 100', 'blend range error changed', scope)

local invalid_style, invalid_style_err = patch.normalize({ bold = 'yes' })
h.assert_true(invalid_style == nil, 'invalid style value was normalized', scope)
h.assert_equal(invalid_style_err, 'Style override bold must be boolean or nil', 'style validation error changed', scope)

local dynamic_spec = {
  version = 1,
  preset = 'pulse',
  duration = 1200,
  loop = 'pingpong',
  timeline = {
    { at = 0, color = 'base' },
    { at = 1, color = '#ffffff' },
  },
}

local normalized, normalize_err = patch.normalize({
  group = ' palette ',
  fg = '#ABCDEF',
  bg = vim.NIL,
  bold = true,
  underline = vim.NIL,
  blend = '42.9',
  dynamic = {
    fg = dynamic_spec,
    sp = vim.NIL,
  },
})
h.assert_true(normalized ~= nil, normalize_err or 'valid patch did not normalize', scope)
h.assert_equal(normalized.group, 'palette', 'group was not trimmed', scope)
h.assert_equal(normalized.fg, '#abcdef', 'color was not normalized', scope)
h.assert_equal(normalized.bg, vim.NIL, 'unset color did not keep sentinel', scope)
h.assert_equal(normalized.bold, true, 'style value changed', scope)
h.assert_equal(normalized.underline, vim.NIL, 'unset style did not keep sentinel', scope)
h.assert_equal(normalized.blend, 42, 'blend was not floored', scope)
h.assert_equal(normalized.dynamic.fg.preset, 'pulse', 'dynamic channel was not normalized', scope)
h.assert_equal(normalized.dynamic.sp, vim.NIL, 'unset dynamic channel did not keep sentinel', scope)
h.assert_true(patch.changes_entry(normalized), 'entry-changing patch was not detected', scope)

local group_only, group_only_err = patch.normalize({ group = 'group-only' })
h.assert_true(group_only ~= nil, group_only_err or 'group-only patch did not normalize', scope)
h.assert_true(not patch.changes_entry(group_only), 'group-only patch was treated as entry-changing', scope)

local empty_dynamic, empty_dynamic_err = patch.normalize({ dynamic = {} })
h.assert_true(empty_dynamic ~= nil, empty_dynamic_err or 'empty dynamic patch did not normalize', scope)
h.assert_true(patch.changes_entry(empty_dynamic), 'empty dynamic patch did not preserve entry-change semantics', scope)

local entry = {
  bg = '#000000',
  underline = true,
  blend = 10,
  dynamic = {
    bg = dynamic_spec,
    sp = dynamic_spec,
  },
}
patch.apply_entry(entry, normalized)
h.assert_equal(entry.fg, '#abcdef', 'normalized color was not applied', scope)
h.assert_true(entry.bg == nil, 'unset color was not cleared', scope)
h.assert_equal(entry.bold, true, 'style was not applied', scope)
h.assert_true(entry.underline == nil, 'unset style was not cleared', scope)
h.assert_equal(entry.blend, 42, 'blend was not applied', scope)
h.assert_equal(entry.dynamic.fg.preset, 'pulse', 'dynamic channel was not applied', scope)
h.assert_true(entry.dynamic.sp == nil, 'unset dynamic channel was not cleared', scope)
h.assert_true(entry.dynamic.bg ~= nil, 'unpatched dynamic channel was removed', scope)

local dynamic_entry = {}
patch.apply_entry(dynamic_entry, { dynamic = { fg = dynamic_spec } })
h.assert_equal(dynamic_entry.dynamic.fg.preset, 'pulse', 'dynamic patch did not create dynamic entry state', scope)

local nil_entry_ok = pcall(patch.apply_entry, nil, normalized)
h.assert_true(not nil_entry_ok, 'patch apply accepted nil entry', scope)
local nil_patch_ok = pcall(patch.apply_entry, entry, nil)
h.assert_true(not nil_patch_ok, 'patch apply accepted nil patch', scope)
local invalid_dynamic_entry_ok = pcall(patch.apply_entry, {
  dynamic = 'broken',
}, {
  dynamic = {
    fg = dynamic_spec,
  },
})
h.assert_true(not invalid_dynamic_entry_ok, 'patch apply replaced invalid entry dynamic value', scope)

patch.apply_entry(entry, { dynamic = { fg = vim.NIL, bg = vim.NIL } })
h.assert_true(entry.dynamic == nil, 'clearing all dynamic channels left an empty dynamic table', scope)

print('hlcraft engine patch: OK')
