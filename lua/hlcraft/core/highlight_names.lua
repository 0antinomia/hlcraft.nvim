local M = {}

local default_label = 'highlight name'

function M.validate(name, label)
  label = label or default_label
  if type(name) ~= 'string' or vim.trim(name) == '' then
    return nil, ('%s must be a non-empty string'):format(label)
  end
  if name:find('[%s|]') then
    return nil, ('%s must not contain whitespace or command separators'):format(label)
  end
  return name, nil
end

function M.assert(name, label, level)
  local normalized, err = M.validate(name, label)
  if not normalized then
    error(err, level or 2)
  end
  return normalized
end

return M
