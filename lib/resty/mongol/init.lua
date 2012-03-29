module("resty.mongol", package.seeall)

local mod_name = (...)

local misc = require ( mod_name .. ".misc" )
local attachpairs_start = misc.attachpairs_start
local opcodes = misc.opcodes
local compose_msg = misc.compose_msg
local full_collection_name = misc.full_collection_name
local docmd = misc.docmd

local assert , pcall = assert , pcall
local ipairs , pairs = ipairs , pairs
local unpack = unpack
local setmetatable = setmetatable
local floor = math.floor
local strbyte , strchar = string.byte , string.char
local strsub = string.sub
local t_insert , t_concat = table.insert , table.concat

local socket = ngx.socket.tcp

local md5 = require "md5"
local md5hex = md5.sumhexa

local ll = require ( mod_name .. ".ll" )
local num_to_le_uint = ll.num_to_le_uint
local num_to_le_int = ll.num_to_le_int
local le_uint_to_num = ll.le_uint_to_num
local le_bpeek = ll.le_bpeek

local getlib = require ( mod_name .. ".get" )
local get_from_string = getlib.get_from_string

local bson = require ( mod_name .. ".bson" )
local to_bson = bson.to_bson
local from_bson = bson.from_bson

local connmethods = { }
local connmt = { __index = connmethods }

local dbmt = require ( mod_name .. ".dbmt" )


function connmethods:cmd(db, q, collection)
	collection = collection or "$cmd"
	local h = self:new_db_handle ( db )
	local c_id , r , t = h:query ( collection , q )

	if t.QueryFailure then
		return nil, "Query Failure"
	elseif not r[1] then
		return nil, "No results returned"
	elseif r[1].ok == 0 then -- Failure
		return nil , r[1].errmsg , r[1] , t
	else
		return r[1]
	end
end

function connmethods:ismaster()
	local r, err = self:cmd("admin", {ismaster = true}) 
    if not r then
        return nil, err
    end
	return r.ismaster, r.hosts
end

local function parse_host ( str )
	local host , port = str:match ( "([^:]+):?(%d*)" )
	port = port or 27017
	return host , port
end

function connmethods:getprimary ( searched )
	searched = searched or { [ self.host .. ":" .. self.port ] = true }

	local r = assert ( self:cmd ( "admin" , { ismaster = true } ) )
	if r.ismaster then return self
	else
		for i , v in ipairs ( r.hosts ) do
			searched [ v ] = true
			local host , port = parse_host ( v )
			local conn = connect ( host , port )

			local found = conn:getprimary ( searched )
			if found then
				return found
			end
		end
	end
	return nil , "No master server found"
end

function connmethods:databases()
	local r = assert ( self:cmd ( "admin" , { listDatabases = true } ) )
	return r.databases
end

function connmethods:shutdown()
	pcall(self.cmd, self, "admin", {shutdown = true})
end

function connmethods:new_db_handle ( db )
    if not db then
        return nil
    end

	return setmetatable ( {
			conn = self ;
			db = db ;
		} , dbmt )
end

function connmethods:set_timeout(timeout)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:settimeout(timeout)
end

function connmethods:set_keepalive(...)
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:setkeepalive(...)
end

function connmethods:get_reused_times()
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:getreusedtimes()
end

function connmethods:connect(host, port)
	self.host = host or self.host
	self.port = port or self.port
    local sock = self.sock

	return sock:connect(self.host, self.port)
end

function connmethods:close()
    local sock = self.sock
    if not sock then
        return nil, "not initialized"
    end

    return sock:close()
end

connmt.__call = connmethods.new_db_handle

function new(self)
	return setmetatable ( {
			sock = socket();
            host = "localhost";
            port = 27017;
		} , connmt )
end

--return new
