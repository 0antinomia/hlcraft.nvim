local h = require('tests.helpers')
local scope = 'hlcraft core highlights'

local highlights = require('hlcraft.core.highlights')

local root = 'HlcraftCoreHighlightsRoot'
local middle = 'HlcraftCoreHighlightsMiddle'
local target = 'HlcraftCoreHighlightsTarget'
vim.api.nvim_set_hl(0, target, { fg = '#abcdef', bg = '#101112' })
vim.api.nvim_set_hl(0, middle, { link = target })
vim.api.nvim_set_hl(0, root, { link = middle })
highlights.invalidate_cache()

local chain = highlights.resolve_link_chain(root)
h.assert_equal(chain[1], root, 'link chain root changed', scope)
h.assert_equal(chain[2], middle, 'link chain middle changed', scope)
h.assert_equal(chain[3], target, 'link chain target changed', scope)

local linked = highlights.get_group(root)
h.assert_equal(linked.link_chain[3], target, 'get_group link chain changed', scope)
h.assert_equal(linked.resolved_fg, '#abcdef', 'get_group resolved fg changed', scope)
h.assert_equal(linked.resolved_bg, '#101112', 'get_group resolved bg changed', scope)

local function find_group(name)
  for _, item in ipairs(highlights.get_all()) do
    if item.name == name then
      return item
    end
  end
  return nil
end

local bulk_linked = find_group(root)
h.assert_true(bulk_linked ~= nil, 'bulk highlight lookup missed linked group', scope)
h.assert_equal(bulk_linked.link_chain[3], target, 'bulk link chain changed', scope)
h.assert_equal(bulk_linked.resolved_fg, '#abcdef', 'bulk resolved fg changed', scope)

local cycle_a = 'HlcraftCoreHighlightsCycleA'
local cycle_b = 'HlcraftCoreHighlightsCycleB'
vim.api.nvim_set_hl(0, cycle_a, { link = cycle_b })
vim.api.nvim_set_hl(0, cycle_b, { link = cycle_a })
highlights.invalidate_cache()
local cycle = highlights.resolve_link_chain(cycle_a)
h.assert_equal(cycle[1], cycle_a, 'cycle chain root changed', scope)
h.assert_equal(cycle[2], cycle_b, 'cycle chain target changed', scope)
h.assert_equal(cycle[3], cycle_a .. ' (circular)', 'cycle marker changed', scope)

local invalid_chain_name_ok = pcall(highlights.resolve_link_chain, nil)
h.assert_true(not invalid_chain_name_ok, 'resolve_link_chain accepted missing name', scope)
local empty_group_name_ok = pcall(highlights.get_group, '')
h.assert_true(not empty_group_name_ok, 'get_group accepted empty name', scope)
local spaced_group_name_ok = pcall(highlights.get_group, 'Bad Name')
h.assert_true(not spaced_group_name_ok, 'get_group accepted whitespace in name', scope)
local command_group_name_ok = pcall(highlights.resolve_link_chain, 'Bad|Name')
h.assert_true(not command_group_name_ok, 'resolve_link_chain accepted command separators in name', scope)

highlights.invalidate_cache()

print('hlcraft core highlights: OK')
