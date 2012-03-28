local mod_name = (...):match ( "^(.*)%..-$" )

local misc = require ( mod_name .. ".misc" )

local assert , pcall = assert , pcall
local ipairs , pairs = ipairs , pairs
local t_insert , t_concat = table.insert , table.concat

local attachpairs_start = misc.attachpairs_start
local docmd = misc.docmd
local opcodes = misc.opcodes
local compose_msg = misc.compose_msg
local full_collection_name = misc.full_collection_name

local ll = require ( mod_name .. ".ll" )
local num_to_le_uint = ll.num_to_le_uint
local num_to_le_int = ll.num_to_le_int
local le_uint_to_num = ll.le_uint_to_num
local le_bpeek = ll.le_bpeek

local bson = require ( mod_name .. ".bson" )
local to_bson = bson.to_bson

local new_cursor = require ( mod_name .. ".cursor" )

local colmethods = { }
local colmt = { __index = colmethods }



function colmethods:insert(docs, continue_on_error)
    if #docs < 1 then
        return nil, "docs needed"
    end

    local flags = 2^0*( continue_on_error and 1 or 0 )

    local t = { }
    for i , v in ipairs(docs) do
        t[i] = to_bson(v)
    end

    local m = num_to_le_uint(flags)..full_collection_name(self, self.col)
                ..t_concat(t)
    return docmd(self.conn, "INSERT", m)
end

function colmethods:update(selector, update, upsert, multiupdate)
    local flags = 2^0*( upsert and 1 or 0 ) + 2^1*( multiupdate and 1 or 0 )

    selector = to_bson(selector)
    update = to_bson(update)

    local m = "\0\0\0\0" .. full_collection_name(self, self.col) 
                .. num_to_le_uint ( flags ) .. selector .. update
    return docmd(self.conn, "UPDATE", m)
end

function colmethods:delete(selector, SingleRemove)
    local flags = 2^0*( SingleRemove and 1 or 0 )

    selector = to_bson(selector)

    local m = "\0\0\0\0" .. full_collection_name(self, self.col) 
                .. num_to_le_uint(flags) .. selector

    return docmd(self.conn, "DELETE", m)
end

function colmethods:kill_cursors(cursorIDs)
    local n = #cursorIDs
    cursorIDs = t_concat(cursorIDs)

    local m = "\0\0\0\0" .. full_collection_name(self, self.col) 
                .. num_to_le_uint(n) .. cursorIDs

    return docmd(self.conn, "KILL_CURSORS", m )
end

function colmethods:query(query, returnfields, numberToSkip, numberToReturn, options)
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

    query = to_bson(query)
    if returnfields then
        returnfields = to_bson(returnfields)
    else
        returnfields = ""
    end

    local m = num_to_le_uint(flags) .. full_collection_name(self, self.col)
        .. num_to_le_uint(numberToSkip) .. num_to_le_int(numberToReturn or -1 )
        .. query .. returnfields

    local req_id = docmd(self.conn, "QUERY", m)
    return handle_reply(self.conn, req_id, numberToSkip)
end

function colmethods:getmore(cursorID, numberToReturn, offset_i)
    local m = "\0\0\0\0" .. full_collection_name(self, self.col) 
                .. num_to_le_int(numberToReturn or 0) .. cursorID

    local req_id = docmd(self.conn, "GET_MORE" , m)
    return handle_reply(self.conn, req_id, offset_i)
end

function colmethods:count(query)
    local r = assert(self.conn:cmd(self.db, attachpairs_start({
            count = self.col;
            query = query or { } ;
        } , "count" ) ) )
    return r.n
end

function colmethods:drop(collection)
    return assert(self.conn:cmd(self.db, {drop = self.col} ) )
end

function colmethods:find(query, returnfields)
    return new_cursor(self.db_obj, self.col, query, returnfields)
end

return colmt
