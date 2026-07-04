local M = {}

function M.fallback_value(result, key)
  result = result or {}
  if key == 'fg' then
    return result.resolved_fg ~= 'NONE' and result.resolved_fg or result.fg
  end
  if key == 'bg' then
    return result.resolved_bg ~= 'NONE' and result.resolved_bg or result.bg
  end
  if key == 'sp' then
    return result.sp
  end
  return result[key]
end

function M.display_text(value)
  if value == nil then
    return 'unset'
  end
  if value == true then
    return 'true'
  end
  if value == false then
    return 'false'
  end
  return tostring(value)
end

return M
