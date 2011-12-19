local getmetatable , setmetatable = getmetatable , setmetatable
local pairs = pairs
local next = next

do
	-- Test to see if __pairs is natively supported
	local supported = false
	local test = setmetatable ( { } , { __pairs = function ( ) supported = true end } )
	pairs ( test )
	if not supported then
		_G.pairs = function ( t )
			local mt = getmetatable ( t )
			if mt then
				local f = mt.__pairs
				if f then
					return f ( t )
				end
			end
			return pairs ( t )
		end
		-- Confirm we added it
		_G.pairs ( test )
		assert ( supported )
	end
end

local pairs_start = function ( t , sk )
	return function ( t , k , v )
			if k == nil then
				return sk , t [ sk ]
			else
				local nk , nv = next ( t , k )
				if nk == nil then
					nk , nv = next ( t )
					return nil
				end
				if nk == sk then
					return nil
				else
					return nk,nv
				end
			end
		end , t
end

local function attachpairs_start ( o , k )
	local mt = getmetatable ( o )
	if not mt then
		mt = { }
		setmetatable ( o , mt )
	end
	mt.__pairs = function ( t )
		return pairs_start ( t , k )
	end
	return o
end

return {
	pairs_start = pairs_start ;
	attachpairs_start = attachpairs_start ;
}
