local h = require('tests.helpers')
local scope = 'hlcraft core search'

local config = require('hlcraft.config')
local highlights = require('hlcraft.core.highlights')
local search = require('hlcraft.core.search')

local names = {
  'HlcraftSearchAlpha',
  'HlcraftSearchBeta',
  'HlcraftSearchSpOnly',
}
local name_set = {}
for _, name in ipairs(names) do
  name_set[name] = true
end

local function local_results(results)
  local filtered = {}
  for _, item in ipairs(results) do
    if name_set[item.name] then
      filtered[#filtered + 1] = item
    end
  end
  return filtered
end

vim.api.nvim_set_hl(0, names[1], { fg = '#101010', bg = '#303030', sp = '#404040' })
vim.api.nvim_set_hl(0, names[2], { fg = '#202020', bg = 'NONE', sp = '#505050' })
vim.api.nvim_set_hl(0, names[3], { fg = '#808080', bg = '#909090', sp = 'NONE', underline = true })
highlights.invalidate_cache()

local by_name = search.by_name('hlcraftsearch')
h.assert_equal(by_name[1].name, names[1], 'name search did not sort by name', scope)
h.assert_equal(by_name[2].name, names[2], 'name search skipped beta', scope)

config.setup({
  include_sp_in_color_search = false,
})
local none_without_sp = search.by_color('NONE', 100)
none_without_sp = local_results(none_without_sp)
h.assert_equal(#none_without_sp, 1, 'NONE search without sp included unexpected local groups', scope)
h.assert_equal(none_without_sp[1].name, names[2], 'NONE search without sp returned wrong group', scope)

config.setup({
  include_sp_in_color_search = true,
})
local none_with_sp = search.by_color('NONE', 100)
none_with_sp = local_results(none_with_sp)
h.assert_equal(none_with_sp[1].name, names[2], 'NONE search with sp did not sort by name', scope)
h.assert_equal(none_with_sp[2].name, names[3], 'NONE search with sp omitted sp-only match', scope)

local by_color = search.by_color('#202020', 64)
by_color = local_results(by_color)
h.assert_equal(by_color[1].name, names[2], 'color search did not return closest match first', scope)
h.assert_equal(by_color[1].distance, 0, 'exact color match distance changed', scope)
h.assert_true(by_color[2].distance > by_color[1].distance, 'color search did not sort by distance', scope)

config.setup({})
highlights.invalidate_cache()

print('hlcraft core search: OK')
