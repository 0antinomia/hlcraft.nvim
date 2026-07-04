local h = require('tests.helpers')
local scope = 'hlcraft highlight entry'

local fields = require('hlcraft.core.fields')
local entry = require('hlcraft.core.highlight_entry')
local highlights = require('hlcraft.core.highlights')

local normal = entry.from_attrs('Normal', {
  fg = tonumber('112233', 16),
  bg = tonumber('445566', 16),
  sp = tonumber('778899', 16),
  bold = true,
  underdashed = true,
  blend = 12,
})
h.assert_equal(normal.name, 'Normal', 'entry name changed', scope)
h.assert_equal(normal.fg, '#112233', 'fg did not normalize', scope)
h.assert_equal(normal.bg, '#445566', 'bg did not normalize', scope)
h.assert_equal(normal.sp, '#778899', 'sp did not normalize', scope)
h.assert_equal(normal.bold, true, 'style flag did not normalize', scope)
h.assert_equal(normal.italic, false, 'missing style flag did not default false', scope)
h.assert_equal(normal.underdashed, true, 'extended style flag did not normalize', scope)
h.assert_equal(normal.blend, 12, 'blend changed', scope)
h.assert_equal(normal.resolved_fg, '#112233', 'non-linked resolved fg changed', scope)
h.assert_equal(normal.resolved_bg, '#445566', 'non-linked resolved bg changed', scope)
local invalid_name_ok = pcall(entry.from_attrs, nil, {})
h.assert_true(not invalid_name_ok, 'entry accepted missing name', scope)
local empty_name_ok = pcall(entry.from_attrs, '', {})
h.assert_true(not empty_name_ok, 'entry accepted empty name', scope)
local invalid_attrs_ok = pcall(entry.from_attrs, 'Invalid', nil)
h.assert_true(not invalid_attrs_ok, 'entry accepted missing attrs', scope)
local invalid_opts_ok = pcall(entry.from_attrs, 'Invalid', {}, false)
h.assert_true(not invalid_opts_ok, 'entry accepted non-table options', scope)
local invalid_resolve_chain_ok = pcall(entry.from_attrs, 'Invalid', {}, { resolve_chain = false })
h.assert_true(not invalid_resolve_chain_ok, 'entry accepted non-function resolve_chain option', scope)
local invalid_resolve_attrs_ok = pcall(entry.from_attrs, 'Invalid', {}, { resolve_attrs = false })
h.assert_true(not invalid_resolve_attrs_ok, 'entry accepted non-function resolve_attrs option', scope)
local invalid_style_ok = pcall(entry.from_attrs, 'Invalid', { bold = 'yes' })
h.assert_true(not invalid_style_ok, 'entry accepted non-boolean style attr', scope)
local invalid_link_ok = pcall(entry.from_attrs, 'Invalid', { link = '' })
h.assert_true(not invalid_link_ok, 'entry accepted empty link attr', scope)
local invalid_color_ok = pcall(entry.from_attrs, 'Invalid', { fg = -1 })
h.assert_true(not invalid_color_ok, 'entry accepted an invalid raw color', scope)
local string_color_ok = pcall(entry.from_attrs, 'Invalid', { fg = '112233' })
h.assert_true(not string_color_ok, 'entry accepted a string raw color', scope)
local invalid_blend_ok = pcall(entry.from_attrs, 'Invalid', { blend = 101 })
h.assert_true(not invalid_blend_ok, 'entry accepted an out-of-range blend', scope)
local fractional_blend_ok = pcall(entry.from_attrs, 'Invalid', { blend = 12.5 })
h.assert_true(not fractional_blend_ok, 'entry accepted a fractional blend', scope)

local style_result = {}
for _, key in ipairs(fields.style_keys) do
  style_result[key] = true
end
h.assert_equal(
  highlights.bool_attrs(style_result),
  table.concat(fields.style_keys, ', '),
  'style attr formatter drifted from core style keys',
  scope
)

local linked = entry.from_attrs('Linked', { link = 'Target' }, {
  resolve_chain = function()
    return { 'Linked', 'Target' }
  end,
  resolve_attrs = function(name)
    h.assert_equal(name, 'Target', 'link terminal name changed', scope)
    return {
      fg = tonumber('abcdef', 16),
      bg = tonumber('010203', 16),
    }
  end,
})
h.assert_equal(linked.fg, 'NONE', 'linked source fg should stay NONE', scope)
h.assert_equal(linked.link_chain[2], 'Target', 'link chain changed', scope)
h.assert_equal(linked.resolved_fg, '#abcdef', 'linked resolved fg changed', scope)
h.assert_equal(linked.resolved_bg, '#010203', 'linked resolved bg changed', scope)

local default_linked = entry.from_attrs('DefaultLinked', { link = 'DefaultTarget' }, {
  resolve_attrs = function(name)
    h.assert_equal(name, 'DefaultTarget', 'default link terminal name changed', scope)
    return {
      fg = tonumber('123456', 16),
    }
  end,
})
h.assert_equal(default_linked.link_chain[1], 'DefaultLinked', 'default link chain source changed', scope)
h.assert_equal(default_linked.link_chain[2], 'DefaultTarget', 'default link chain target changed', scope)
h.assert_equal(default_linked.resolved_fg, '#123456', 'default linked resolved fg changed', scope)

local default_circular = entry.from_attrs('DefaultCircular', { link = 'DefaultCircular' })
h.assert_equal(default_circular.link_chain[2], 'DefaultCircular (circular)', 'default circular marker changed', scope)

local invalid_chain_result_ok = pcall(entry.from_attrs, 'InvalidLinked', { link = 'Target' }, {
  resolve_chain = function()
    return 'Target'
  end,
})
h.assert_true(not invalid_chain_result_ok, 'entry accepted a non-table link chain result', scope)
local empty_chain_result_ok = pcall(entry.from_attrs, 'InvalidLinked', { link = 'Target' }, {
  resolve_chain = function()
    return {}
  end,
})
h.assert_true(not empty_chain_result_ok, 'entry accepted an empty link chain result', scope)
local sparse_chain_result_ok = pcall(entry.from_attrs, 'InvalidLinked', { link = 'Target' }, {
  resolve_chain = function()
    return { [2] = 'Target' }
  end,
})
h.assert_true(not sparse_chain_result_ok, 'entry accepted a sparse link chain result', scope)
local invalid_chain_entry_ok = pcall(entry.from_attrs, 'InvalidLinked', { link = 'Target' }, {
  resolve_chain = function()
    return { 'InvalidLinked', false }
  end,
})
h.assert_true(not invalid_chain_entry_ok, 'entry accepted a non-string link chain entry', scope)
local invalid_attrs_result_ok = pcall(entry.from_attrs, 'InvalidLinked', { link = 'Target' }, {
  resolve_attrs = function()
    return false
  end,
})
h.assert_true(not invalid_attrs_result_ok, 'entry accepted a non-table resolved attrs result', scope)
local invalid_resolved_color_ok = pcall(entry.from_attrs, 'InvalidResolvedColor', { link = 'Target' }, {
  resolve_attrs = function()
    return {
      fg = 0x1000000,
    }
  end,
})
h.assert_true(not invalid_resolved_color_ok, 'entry accepted an invalid resolved color', scope)

local circular = entry.from_attrs('Circular', { link = 'Circular' }, {
  resolve_chain = function()
    return { 'Circular', 'Circular (circular)' }
  end,
  resolve_attrs = function(name)
    h.assert_equal(name, 'Circular', 'circular suffix was not stripped', scope)
    return {
      fg = tonumber('999999', 16),
    }
  end,
})
h.assert_equal(circular.resolved_fg, '#999999', 'circular resolved fg changed', scope)
h.assert_equal(circular.resolved_bg, 'NONE', 'missing circular resolved bg should be NONE', scope)

print('hlcraft highlight entry: OK')
