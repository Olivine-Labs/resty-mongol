local mod_name = (...):match ( "^(.*)%..-$" )

local setmetatable = setmetatable
local strbyte = string.byte
local strformat = string.format
local t_insert = table.insert
local t_concat = table.concat

local md5 = require "md5"
local hasposix , posix = pcall ( require , "posix" )

local ll = require ( mod_name .. ".ll" )
local num_to_le_uint = ll.num_to_le_uint
local num_to_be_uint = ll.num_to_be_uint

local object_id_mt = {
	__tostring = function ( ob )
		local t = { }
		for i = 1 , 12 do
			t_insert ( t , strformat ( "%02x" , strbyte ( ob.id , i , i ) ) )
		end
		return "ObjectId(" .. t_concat ( t ) .. ")"
	end ;
	__eq = function ( a , b ) return a.id == b.id end ;
}

local machineid
if hasposix then
	machineid = posix.uname ( "%n" )
else
	machineid = assert ( io.popen ( "uname -n" ) ):read ( "*l" )
end
machineid = md5.sum ( machineid ):sub ( 1 , 3 )

local pid
if hasposix then
	pid = posix.getpid ( ).pid
else
	pid = assert ( tonumber ( assert ( io.popen ( "ps -o ppid= -p $$") ):read ( "*a" ) ) )
end
pid = num_to_le_uint ( pid , 2 )

local inc = 0
local function generate_id ( )
	inc = inc + 1
	-- "A BSON ObjectID is a 12-byte value consisting of a 4-byte timestamp (seconds since epoch), a 3-byte machine id, a 2-byte process id, and a 3-byte counter. Note that the timestamp and counter fields must be stored big endian unlike the rest of BSON"
	return num_to_be_uint ( os.time ( ) , 4 ) .. machineid .. pid .. num_to_be_uint ( inc , 3 )
end

local function new_object_id ( str )
	if str then
		assert ( #str == 12 )
	else
		str = generate_id ( )
	end
	return setmetatable ( { id = str } , object_id_mt )
end

return {
	new = new_object_id ;
	metatable = object_id_mt ;
}
