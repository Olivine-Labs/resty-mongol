local bson = require "mongol.bson"
local to_bson = bson.to_bson
local from_bson = bson.from_bson

local getlib = require "mongol.get"
local obid = require "mongol.object_id"

local o = {
	a = "lol" ;
	b = "foo" ;
	c = 42 ;
	d = { 5 , 4 , 3 , 2 , 1 } ;
	e = { { { { } } } } ;
	f = { [true] = {baz = "mars"} } ;
	g = obid.new ( "abcdefghijkl" )
	--z = { [{}] = {} } ; -- Can't test as tables are unique
}
local b = to_bson ( o )
local t = from_bson ( getlib.get_from_string ( b ) )

local function confirm ( orig , new , d )
	d = d or 1
	local ok = true
	for k ,v in pairs ( orig ) do
		local nv = new [ k ]
		--print(string.rep ( "\t" , d-1) , "KEY", type(k),k, "VAL",type(v),v,"NEWVAL",type(nv),nv)
		if nv == v then
		elseif type ( v ) == "table" and type ( nv ) == "table" then
			--print(string.rep ( "\t" , d-1) , "Descending" , k )
			ok = ok and confirm ( v , nv , d+1 )
		else
			print(string.rep ( "\t" , d-1) , "Failed on" , k , v , nv )
			ok = false
		end
	end
	return ok
end

assert ( confirm ( o , t ) )
assert ( to_bson ( t ) == to_bson ( t ) )
assert ( to_bson ( t ) == b )
