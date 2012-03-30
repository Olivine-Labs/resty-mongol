local mod_name = (...):match ( "^(.*)%..-$" )

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

local md5 = require "md5"
local md5hex 
if not md5 then
    resty_md5 = require "resty.md5"
    md5hex = function(str)
        md5 = resty_md5:new()
        md5:update(str)
        return md5:final()
    end
else
    md5hex = md5.sumhexa
end

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

local new_cursor = require ( mod_name .. ".cursor" )

local colmt = require ( mod_name .. ".colmt" )


local dbmethods = { }
local dbmt = { __index = dbmethods }

function dbmethods:update ( collection , selector , update , upsert , multiupdate )
    local flags = 2^0*( upsert and 1 or 0 ) + 2^1*( multiupdate and 1 or 0 )

    selector = to_bson ( selector )
    update = to_bson ( update )

    local m = "\0\0\0\0" .. full_collection_name ( self , collection ) .. num_to_le_uint ( flags ) .. selector .. update
    return docmd ( self.conn , "UPDATE" , m )
end

function dbmethods:insert ( collection , docs , continue_on_error )
    assert ( #docs >= 1 )

    local flags = 2^0*( continue_on_error and 1 or 0 )

    local t = { }
    for i , v in ipairs ( docs ) do
        t [ i ] = to_bson ( v )
    end

    local m = num_to_le_uint ( flags ) .. full_collection_name ( self , collection ) .. t_concat ( t )
    return docmd ( self.conn , "INSERT" , m )
end

function dbmethods:delete ( collection , selector , SingleRemove )
    local flags = 2^0*( SingleRemove and 1 or 0 )

    selector = to_bson ( selector )

    local m = "\0\0\0\0" .. full_collection_name ( self , collection ) .. num_to_le_uint ( flags ) .. selector

    return docmd ( self.conn , "DELETE" , m )
end

function dbmethods:kill_cursors ( collection , cursorIDs )
    local n = #cursorIDs
    cursorIDs = t_concat ( cursorIDs )

    local m = "\0\0\0\0" .. full_collection_name ( self , collection ) .. num_to_le_uint ( n ) .. cursorIDs

    return docmd ( self.conn , "KILL_CURSORS" , m )
end

local function read_msg_header ( sock )
    local header = assert ( sock:receive ( 16 ) )

    local length = le_uint_to_num ( header , 1 , 4 )
    local requestID = le_uint_to_num ( header , 5 , 8 )
    local reponseTo = le_uint_to_num ( header , 9 , 12 )
    local opcode = le_uint_to_num ( header , 13 , 16 )

    return length , requestID , reponseTo , opcode
end

local function handle_reply ( conn , req_id , offset_i )
    offset_i = offset_i  or 0

    local r_len , r_req_id , r_res_id , opcode = read_msg_header ( conn.sock )
    assert ( req_id == r_res_id )
    assert ( opcode == opcodes.REPLY )
    local data = assert ( conn.sock:receive ( r_len - 16 ) )
    local get = get_from_string ( data )

    local responseFlags = get ( 4 )
    local cursorid = get ( 8 )

    local t = { }
    t.startingFrom = le_uint_to_num ( get ( 4 ) )
    t.numberReturned = le_uint_to_num ( get ( 4 ) )
    t.CursorNotFound = le_bpeek ( responseFlags , 0 )
    t.QueryFailure = le_bpeek ( responseFlags , 1 )
    t.ShardConfigStale = le_bpeek ( responseFlags , 2 )
    t.AwaitCapable = le_bpeek ( responseFlags , 3 )

    local r = { }
    for i = 1 , t.numberReturned do
        r [ i + offset_i ] = from_bson ( get )
    end

    return cursorid , r , t
end

function dbmethods:query ( collection , query , returnfields , numberToSkip , numberToReturn , options )
    numberToSkip = numberToSkip or 0

    local flags = 0
    if options then
        flags = 2^1*( options.TailableCursor and 1 or 0 )
            + 2^2*( options.SlaveOk and 1 or 0 )
            + 2^3*( options.OplogReplay and 1 or 0 )
            + 2^4*( options.NoCursorTimeout and 1 or 0 )
            + 2^5*( options.AwaitData and 1 or 0 )
            + 2^6*( options.Exhaust and 1 or 0 )
            + 2^7*( options.Partial and 1 or 0 )
    end

    query = to_bson ( query )
    if returnfields then
        returnfields = to_bson ( returnfields )
    else
        returnfields = ""
    end

    local m = num_to_le_uint ( flags ) .. full_collection_name ( self , collection )
        .. num_to_le_uint ( numberToSkip ) .. num_to_le_int ( numberToReturn or -1 )
        .. query .. returnfields

    local req_id = docmd ( self.conn , "QUERY" , m )
    return handle_reply ( self.conn , req_id , numberToSkip )
end

function dbmethods:getmore ( collection , cursorID , numberToReturn , offset_i )
    local m = "\0\0\0\0" .. full_collection_name ( self , collection ) .. num_to_le_int ( numberToReturn or 0 ) .. cursorID

    local req_id = docmd ( self.conn , "GET_MORE" , m )
    return handle_reply ( self.conn , req_id , offset_i )
end

-- Util functions

-- returns a cursor
dbmethods.find = new_cursor

function dbmethods:count ( collection , query )
    local r = assert ( self.conn:cmd ( self.db , attachpairs_start ( {
            count = collection ;
            query = query or { } ;
        } , "count" ) ) )
    return r.n
end

function dbmethods:listcollections ( )
    return self:find ( "system.namespaces" , { } )
end

function dbmethods:drop ( collection )
    return assert ( self.conn:cmd ( self.db , { drop = collection } ) )
end

function dbmethods:dropDatabase ( )
    return assert ( self.conn:cmd ( self.db , { dropDatabase = true } ) )
end

local function pass_digest ( username , password )
    return md5hex ( username .. ":mongo:" .. password )
end

function dbmethods:add_user ( username , password )
    local digest = pass_digest ( username , password )
    return self:update ( "system.users" , { user = username } , { ["$set"] = { pwd = password } } , true )
end

function dbmethods:auth ( username , password )
    local r = assert ( self.conn:cmd ( self.db , { getnonce = true } ) )
    local digest = md5hex ( r.nonce .. username .. pass_digest ( username , password ) )

    return self.conn:cmd ( self.db , attachpairs_start ({
            authenticate = true ;
            user = username ;
            nonce = r.nonce ;
            key = digest ;
         } , "authenticate" ) ) ~= nil
end

function dbmethods:get_col(collection)
    if not collection then
        return nil, "collection needed"
    end   

    return setmetatable ( {
            conn = self.conn;
            db_obj = self;
            db = self.db ;
            col = collection;
        } , colmt )
end

return dbmt
