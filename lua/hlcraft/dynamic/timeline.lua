local M = {}

local numbers = require('hlcraft.core.number')

local function curve(amount, interpolation)
  amount = numbers.unit(amount, 0)
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
  duration = numbers.to_finite(duration, 0)
  if duration <= 0 then
    return 0
  end

  local raw = (numbers.to_finite(now_ms, 0) / duration) + numbers.to_finite(phase_offset, 0)
  if loop == 'once' then
    return numbers.unit(raw, 0)
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

  phase = numbers.unit(phase, 0)
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
