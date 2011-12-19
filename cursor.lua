local t_insert = table.insert
local t_remove = table.remove
local t_concat = table.concat
local strbyte = string.byte
local strformat = string.format


local cursor_methods = { }
local cursor_mt = { __index = cursor_methods }

local function new_cursor ( conn , collection , query , returnfields )
	return setmetatable ( {
			conn = conn ;
			collection = collection ;
			query = query ;
			returnfields = returnfields ;

			id = false ;
			results = { } ;

			done = false ;
			i = 0 ;
		} , cursor_mt )
end

cursor_mt.__gc = function ( self )
	self.conn:kill_cursors ( self.collection , { self.id } )
end

cursor_mt.__tostring = function ( ob )
	local t = { }
	for i = 1 , 8 do
		t_insert ( t , strformat ( "%02x" , strbyte ( ob.id , i , i ) ) )
	end
	return "CursorId(" .. t_concat ( t ) .. ")"
end

function cursor_methods:next ( )
	local v = self.results [ self.i + 1 ]
	if v ~= nil then
		self.i = self.i + 1
		self.results [ self.i ] = nil
		return self.i , v
	end

	if self.done then return nil end

	local t
	if not self.id then
		self.id , self.results , t = self.conn:query ( self.collection , self.query , self.returnfields , self.i , 0 )
		if self.id == "\0\0\0\0\0\0\0\0" then
			self.done = true
		end
	else
		self.id , self.results , t = self.conn:getmore ( self.collection , self.id , 0 , self.i )
		if self.id == "\0\0\0\0\0\0\0\0" then
			self.done = true
		elseif t.CursorNotFound then
			self.id = false
		end
	end
	return self:next ( )
end

function cursor_methods:pairs ( )
	return self.next , self
end

return new_cursor
