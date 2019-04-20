local skip_duplicate = function ( t, sk, k )
  local nk, nv
  if k then
    nk, nv = next(t, k)
  else
    nk, nv = next(t)
  end

  while nk and nk == sk do
    nk, nv = next(t, nk)
  end
  return nk, nv
end

-- substitute pairs function to bump up the provided argument to be the first item in the list
local pairs_start = function ( t , sk )
  local i = 0
  return function(t, k, v)
    i = i + 1
    local nk, nv
    if i == 1 then
      return sk, t[sk]
    elseif i == 2 then
      nk, nv = skip_duplicate( t, sk )
    else
      nk, nv = skip_duplicate( t, sk, k )
    end
    return nk,nv
  end,
  t
end

local function attachpairs_start ( o , k )
  local mt = getmetatable(o)
  if not mt then
    mt = {}
    setmetatable(o, mt)
  end
  mt.__pairs = function (t)
    return pairs_start (t, k)
  end
  return o
end

return {
  pairs_start = pairs_start,
  attachpairs_start = attachpairs_start
}

