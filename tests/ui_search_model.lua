local h = require('tests.helpers')
local scope = 'hlcraft ui search model'

local model = require('hlcraft.ui.search_model')

h.assert_equal(
  model.empty_message('', ''),
  'Use Name and Color search together to narrow highlight groups',
  'empty search message changed',
  scope
)
h.assert_equal(
  model.empty_message('Normal', '#ffffff'),
  'No highlight groups match both the name and color filters',
  'combined empty message changed',
  scope
)
h.assert_equal(
  model.empty_message('', '#ffffff'),
  'No highlight groups match this color filter',
  'color empty message changed',
  scope
)
h.assert_equal(
  model.empty_message('Normal', ''),
  'No highlight groups match this name filter',
  'name empty message changed',
  scope
)

h.assert_true(model.valid_color_query('#abcdef'), 'valid hex color query was rejected', scope)
h.assert_true(model.valid_color_query('NONE'), 'NONE color query was rejected', scope)
h.assert_true(not model.valid_color_query('not-a-color'), 'invalid color query was accepted', scope)
h.assert_true(not model.valid_color_query(123), 'numeric color query was accepted', scope)

local intersection = model.intersect({
  { name = 'Gamma', fg = '#000000' },
  { name = 'Alpha', fg = '#111111' },
  { name = 'Beta', fg = '#222222' },
}, {
  { name = 'Beta', distance = 5 },
  { name = 'Gamma', distance = 2 },
  { name = 'Alpha', distance = 5 },
})
h.assert_equal(intersection[1].name, 'Gamma', 'intersection did not sort by distance', scope)
h.assert_equal(intersection[2].name, 'Alpha', 'intersection did not tie-break by name', scope)
h.assert_equal(intersection[3].name, 'Beta', 'intersection omitted a shared result', scope)
h.assert_equal(intersection[2].distance, 5, 'intersection did not carry color distance', scope)
local nil_intersect_ok = pcall(model.intersect, nil, {})
h.assert_true(not nil_intersect_ok, 'search model accepted nil name results', scope)
local sparse_intersect_ok = pcall(model.intersect, {
  [2] = { name = 'Late' },
}, {})
h.assert_true(not sparse_intersect_ok, 'search model accepted sparse name results', scope)

local provider_calls = {}
local provider = {
  by_name = function(query)
    provider_calls[#provider_calls + 1] = 'name:' .. query
    return {
      { name = 'Alpha' },
      { name = 'Beta' },
    }
  end,
  by_color = function(query)
    provider_calls[#provider_calls + 1] = 'color:' .. query
    return {
      { name = 'Beta', distance = 1 },
    }
  end,
}

local combined = model.results('a', '#ffffff', provider)
h.assert_equal(combined[1].name, 'Beta', 'combined search did not intersect providers', scope)
h.assert_equal(#provider_calls, 2, 'combined search did not call both providers', scope)
h.assert_equal(provider_calls[1], 'name:a', 'combined search called name provider incorrectly', scope)
h.assert_equal(provider_calls[2], 'color:#ffffff', 'combined search called color provider incorrectly', scope)

provider_calls = {}
local invalid = model.results('a', 'invalid', provider)
h.assert_equal(#invalid, 0, 'invalid combined color query returned results', scope)
h.assert_equal(#provider_calls, 0, 'invalid combined color query called providers', scope)

local non_string_ok = pcall(model.results, 123, 456, provider)
h.assert_true(not non_string_ok, 'search model accepted non-string queries', scope)
local non_string_empty_message_ok = pcall(model.empty_message, 123, '')
h.assert_true(not non_string_empty_message_ok, 'search empty message accepted non-string query', scope)
local invalid_provider_ok = pcall(model.results, '', '', false)
h.assert_true(not invalid_provider_ok, 'search model accepted invalid provider', scope)
local incomplete_provider_ok = pcall(model.results, '', '', {
  by_name = function()
    return {}
  end,
})
h.assert_true(not incomplete_provider_ok, 'search model accepted incomplete provider', scope)
local invalid_provider_result_ok = pcall(model.results, 'Alpha', '', {
  by_name = function()
    return nil
  end,
  by_color = function()
    return {}
  end,
})
h.assert_true(not invalid_provider_result_ok, 'search model accepted invalid provider results', scope)
local invalid_provider_item_ok = pcall(model.results, 'Alpha', '', {
  by_name = function()
    return { false }
  end,
  by_color = function()
    return {}
  end,
})
h.assert_true(not invalid_provider_item_ok, 'search model accepted invalid provider result item', scope)
local nameless_provider_item_ok = pcall(model.results, 'Alpha', '', {
  by_name = function()
    return { {} }
  end,
  by_color = function()
    return {}
  end,
})
h.assert_true(not nameless_provider_item_ok, 'search model accepted nameless provider result item', scope)
local sparse_provider_result_ok = pcall(model.results, 'Alpha', '', {
  by_name = function()
    return {
      [2] = { name = 'Late' },
    }
  end,
  by_color = function()
    return {}
  end,
})
h.assert_true(not sparse_provider_result_ok, 'search model accepted sparse provider results', scope)

provider_calls = {}
local color_only = model.results('', 'NONE', provider)
h.assert_equal(color_only[1].name, 'Beta', 'color-only search did not use color provider', scope)
h.assert_equal(#provider_calls, 1, 'color-only search called wrong number of providers', scope)
h.assert_equal(provider_calls[1], 'color:NONE', 'color-only search called wrong provider', scope)

provider_calls = {}
local name_only = model.results('Alpha', '', provider)
h.assert_equal(name_only[1].name, 'Alpha', 'name-only search did not use name provider', scope)
h.assert_equal(#provider_calls, 1, 'name-only search called wrong number of providers', scope)
h.assert_equal(provider_calls[1], 'name:Alpha', 'name-only search called wrong provider', scope)

print('hlcraft ui search model: OK')
