local h = require('tests.helpers')
local scope = 'hlcraft core presets'

local presets = require('hlcraft.core.presets')

local core = presets.transparent('core')
h.assert_equal(core.Normal.bg, 'NONE', 'core transparent preset omitted Normal', scope)
h.assert_true(core.Pmenu == nil, 'core transparent preset included extended groups', scope)

local extended = presets.transparent('extended')
h.assert_equal(extended.Normal.bg, 'NONE', 'extended transparent preset omitted core groups', scope)
h.assert_equal(extended.Pmenu.bg, 'NONE', 'extended transparent preset omitted extended groups', scope)

local default = presets.transparent()
h.assert_equal(default.Pmenu.bg, 'NONE', 'default transparent preset stopped using extended scope', scope)

local invalid_scope_ok = pcall(presets.transparent, 'bad')
h.assert_true(not invalid_scope_ok, 'transparent preset accepted an invalid scope', scope)
local invalid_scope_type_ok = pcall(presets.transparent, false)
h.assert_true(not invalid_scope_type_ok, 'transparent preset accepted a non-string scope', scope)

print('hlcraft core presets: OK')
