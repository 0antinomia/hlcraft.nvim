local h = require('tests.helpers')
local scope = 'hlcraft highlight entry'

local entry = require('hlcraft.core.highlight_entry')

local normal = entry.from_attrs('Normal', {
  fg = tonumber('112233', 16),
  bg = tonumber('445566', 16),
  sp = tonumber('778899', 16),
  bold = true,
  blend = 12,
})
h.assert_equal(normal.name, 'Normal', 'entry name changed', scope)
h.assert_equal(normal.fg, '#112233', 'fg did not normalize', scope)
h.assert_equal(normal.bg, '#445566', 'bg did not normalize', scope)
h.assert_equal(normal.sp, '#778899', 'sp did not normalize', scope)
h.assert_equal(normal.bold, true, 'style flag did not normalize', scope)
h.assert_equal(normal.italic, false, 'missing style flag did not default false', scope)
h.assert_equal(normal.blend, 12, 'blend changed', scope)
h.assert_equal(normal.resolved_fg, '#112233', 'non-linked resolved fg changed', scope)
h.assert_equal(normal.resolved_bg, '#445566', 'non-linked resolved bg changed', scope)

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
