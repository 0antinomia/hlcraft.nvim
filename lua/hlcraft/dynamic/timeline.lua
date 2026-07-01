local M = {}

local function clamp_unit(value)
  value = tonumber(value) or 0
  if value < 0 then
    return 0
  end
  if value > 1 then
    return 1
  end
  return value
end

local function curve(amount, interpolation)
  amount = clamp_unit(amount)
  if interpolation == 'step' then
    return 0
  end
  if interpolation == 'smooth' or interpolation == 'smoothstep' then
    return amount * amount * (3 - (2 * amount))
  end
  if interpolation == 'sine' then
    return (1 - math.cos(amount * math.pi)) / 2
  end
  return amount
end

function M.phase(now_ms, duration, phase_offset, loop)
  duration = tonumber(duration) or 0
  if duration <= 0 then
    return 0
  end

  local raw = ((tonumber(now_ms) or 0) / duration) + (tonumber(phase_offset) or 0)
  if loop == 'once' then
    return clamp_unit(raw)
  end
  if loop == 'pingpong' then
    local wrapped = raw % 2
    if wrapped > 1 then
      return 2 - wrapped
    end
    return wrapped
  end
  return raw % 1
end

function M.sample(stops, phase, interpolation, interpolate)
  if type(stops) ~= 'table' or #stops == 0 then
    return nil
  end
  if #stops == 1 then
    return stops[1]
  end

  phase = clamp_unit(phase)
  if phase <= stops[1].at then
    return stops[1]
  end

  for index = 2, #stops do
    local right = stops[index]
    if phase <= right.at then
      local left = stops[index - 1]
      local span = right.at - left.at
      local amount = span <= 0 and 0 or (phase - left.at) / span
      amount = curve(amount, interpolation)

      if interpolation == 'step' or not interpolate then
        return left
      end
      return interpolate(left, right, amount)
    end
  end

  return stops[#stops]
end

function M.sample_numeric(stops, phase, interpolation)
  local sampled = M.sample(stops, phase, interpolation, function(left, right, amount)
    return {
      at = phase,
      value = left.value + ((right.value - left.value) * amount),
    }
  end)

  return sampled and sampled.value or nil
end

return M
