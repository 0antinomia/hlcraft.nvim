local M = {}

local function concat_lists(...)
  local result = {}
  for _, list in ipairs({ ... }) do
    for _, key in ipairs(list) do
      result[#result + 1] = key
    end
  end
  return result
end

local function key_set(keys)
  local result = {}
  for _, key in ipairs(keys) do
    result[key] = true
  end
  return result
end

M.color_keys = { 'fg', 'bg', 'sp' }
M.style_keys = {
  'bold',
  'italic',
  'underline',
  'undercurl',
  'strikethrough',
  'underdouble',
  'underdotted',
  'underdashed',
}
M.numeric_keys = { 'blend' }

M.override_keys = concat_lists(M.color_keys, M.style_keys, M.numeric_keys)

M.color_set = key_set(M.color_keys)
M.style_set = key_set(M.style_keys)
M.override_set = key_set(M.override_keys)

return M
