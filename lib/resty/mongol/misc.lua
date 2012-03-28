local mod_name = (...):match ( "^(.*)%..-$" )

local ll = require ( mod_name .. ".ll" )
local num_to_le_uint = ll.num_to_le_uint
local num_to_le_int = ll.num_to_le_int
local le_uint_to_num = ll.le_uint_to_num
local le_bpeek = ll.le_bpeek


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

local opcodes = {
	REPLY = 1 ;
	MSG = 1000 ;
	UPDATE = 2001 ;
	INSERT = 2002 ;
	QUERY = 2004 ;
	GET_MORE = 2005 ;
	DELETE = 2006 ;
	KILL_CURSORS = 2007 ;
}

local function compose_msg ( requestID , reponseTo , opcode , message )
	return num_to_le_uint ( #message + 16 ) .. requestID .. reponseTo .. opcode .. message
end

local function full_collection_name ( self , collection )
	local db = assert ( self.db , "Not current in a database" )
	return  db .. "." .. collection .. "\0"
end

local id = 0
local function docmd ( conn , opcode , message ,  reponseTo )
	id = id + 1
	local requestID = num_to_le_uint ( id )
	reponseTo = reponseTo or "\255\255\255\255"
	opcode = num_to_le_uint ( assert ( opcodes [ opcode ] ) )

	local m = compose_msg ( requestID , reponseTo , opcode , message )
	local sent = assert ( conn.sock:send ( m ) )

	return id , sent
end

return {
	pairs_start = pairs_start ;
	attachpairs_start = attachpairs_start ;
	opcodes = opcodes;
	compose_msg = compose_msg;
	full_collection_name = full_collection_name;
	docmd = docmd;
}
