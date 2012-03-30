local mod_name = (...):match ( "^(.*)%..-$" )

local misc = require ( mod_name .. ".misc" )
local attachpairs_start = misc.attachpairs_start

local setmetatable = setmetatable
local assert , pcall = assert , pcall

local md5 = require "md5"
local md5hex = md5.sumhexa

local colmt = require ( mod_name .. ".colmt" )

local dbmethods = { }
local dbmt = { __index = dbmethods }

function dbmethods:cmd(q)
    collection = "$cmd"
    col = self:get_col(collection)
    
    local c_id , r , t = col:query(q)

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

function dbmethods:listcollections ( )
    local col = self:get_col("system.namespaces")
    return col:find( { } )
end

function dbmethods:dropDatabase ( )
    return assert ( self:cmd({ dropDatabase = true }))
end

local function pass_digest ( username , password )
    return md5hex ( username .. ":mongo:" .. password )
end

function dbmethods:add_user ( username , password )
    local digest = pass_digest ( username , password )
    return self:update ( "system.users" , { user = username } , { ["$set"] = { pwd = password } } , true )
end

function dbmethods:auth(username, password)
    local r = assert ( self:cmd({ getnonce = true }))
 
    local digest = md5hex ( r.nonce .. username .. pass_digest ( username , password ) )

    return self:cmd(attachpairs_start({
            authenticate = true ;
            user = username ;
            nonce = r.nonce ;
            key = digest ;
         } , "authenticate" ) )
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
