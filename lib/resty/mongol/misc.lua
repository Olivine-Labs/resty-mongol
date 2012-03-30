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

local getlib = require ( mod_name .. ".get" )
local get_from_string = getlib.get_from_string

local bson = require ( mod_name .. ".bson" )
local from_bson = bson.from_bson

local pairs_start = function ( t , sk )
    local i = 0
    return function ( t , k , v )
        i = i + 1
        local nk, nv
        if i == 1 then
            return sk, t[sk]
        elseif i == 2 then
            nk, nv = next(t)
        else
            nk, nv = next(t, k)
        end
        return nk,nv
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

return {
    pairs_start = pairs_start ;
    attachpairs_start = attachpairs_start ;
    opcodes = opcodes;
    compose_msg = compose_msg;
    full_collection_name = full_collection_name;
    docmd = docmd;
    handle_reply = handle_reply;
}
