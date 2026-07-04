local M = {}

local constants = require('hlcraft.dynamic.constants')
local numbers = require('hlcraft.core.number')

local function curve(amount, interpolation)
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
  if
    not numbers.is_finite(now_ms)
    or not numbers.is_finite(duration)
    or duration <= 0
    or not numbers.is_finite(phase_offset)
    or not constants.loop_set[loop]
  then
    return nil
  end

  local raw = (now_ms / duration) + phase_offset
  if loop == 'once' then
    return numbers.unit(raw)
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
  if
    type(stops) ~= 'table'
    or #stops == 0
    or not numbers.is_finite(phase)
    or not constants.interpolation_set[interpolation]
  then
    return nil
  end
  if #stops == 1 then
    return stops[1]
  end

  phase = numbers.unit(phase)
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
