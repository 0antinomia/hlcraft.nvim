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

provider_calls = {}
local non_string = model.results(123, 456, provider)
h.assert_equal(#non_string, 0, 'non-string query returned results', scope)
h.assert_equal(#provider_calls, 0, 'non-string query called providers', scope)

provider_calls = {}
local non_string_name = model.results(123, 'NONE', provider)
h.assert_equal(#non_string_name, 0, 'non-string name query returned results', scope)
h.assert_equal(#provider_calls, 0, 'non-string name query called providers', scope)

provider_calls = {}
local non_string_color = model.results('Alpha', 456, provider)
h.assert_equal(#non_string_color, 0, 'non-string color query returned results', scope)
h.assert_equal(#provider_calls, 0, 'non-string color query called providers', scope)

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
