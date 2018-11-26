Name
======
lua-resty-mongol - Native Lua Mongodb driver which supports both luasocket and ngx_lua based on the cosocket API

Thanks to project Mongol by daurnimator

copied and relicensed with permission from git://github.com/bigplum/lua-resty-mongol.git

Dependencies
======

luajit(or `attempt to yield across metamethod/C-call boundary error` will be produced.)

[ngx_lua 0.5.0rc5](https://github.com/chaoslawful/lua-nginx-module/tags) or [ngx_openresty 1.0.11.7](http://openresty.org/#Download) is required.


Installation
======

		luarocks install resty-mongol --server=http://rocks.moonscript.org

Usage
======

Add package path into nginx.conf. (only if not using luarocks)

        lua_package_path '/usr/local/openresty/lualib/?/init.lua;;';

or into lua files before requiring. (only if not using luarocks)

        local p = "/usr/local/openresty/lualib/"
        local m_package_path = package.path
        package.path = string.format("%s?.lua;%s?/init.lua;%s",
            p, p, m_package_path)

Requring the module will return a function that connects to mongod:
it takes a host (default localhost) and a port (default 27017);
it returns a connection object.

		mongol = require "resty-mongol"
		conn = mongol() -- return a connection object

###Connection objects have server wide methods.
------------

####ok,err = conn:connect(host, port)
Default host and port is: `localhost` and `27017`.

####ok,err = conn:set_timeout(msec)
Sets socket connecting, reading, writing timeout value, unit is milliseconds.

In case of success, returns 1. In case of errors, returns nil with a string describing the error.

####ok,err = conn:set_keepalive(msec, pool_size)
Keeps the socket alive for `msec` by ngx_lua cosocket.

In case of success, returns 1. In case of errors, returns nil with a string describing the error.

####times,err = conn:get_reused_times()
Returns the socket reused times.

In case of success, returns times. In case of errors, returns nil with a string describing the error.

####ok,err = conn:close()
Closes the connection.

In case of success, returns 1. In case of errors, returns nil with a string describing the error.

####bool, hosts = conn:ismaster()
Returns a boolean indicating if this is the master server and a table of other hosts this server is replicating with
or `nil, err` on failure.

####newconn = conn:getprimary ( [already_checked] )
Returns a new connection object that is connected to the primary server
or `nil , errmsg` on failure.

The returned connection object may be this connection object itself.


####databases = conn:databases ( )
Returns a table describing databases on the server.

		databases.name: string
		databases.empty: boolean
		databases.sizeOnDisk: number

####conn:shutdown()
Shutsdown the server. Returns nothing.

####db = conn:new_db_handle(database_name)
Returns a database object, or nil.

###Database objects perform actions on a database
------------

####db:list()

####db:dropDatabase()

####db:add_user(username, password)

####ok, err = db:auth(username, password)
Returns 1 in case of success, or nil with error message.

####col = db:get_col(collection_name)
Returns a collection object for more operations.

####gridfs = db:get_gridfs(fs)

###Collection objects
------------

####n = col:count(query)

####ok, err = col:drop()
Returns 1 in case of success, or nil with error message.

####n, err = col:update(selector, update, upsert, multiupdate, safe)
Returns number of rows been updated or nil for error.

 - upsert, if set to `1`, the database will insert the supplied object into the collection if no matching document is found, default to `0`.
 - multiupdate, if set to `1`, the database will update all matching objects in the collection. Otherwise only updates first matching doc, default to `0`. Multi update only works with $ operators.
 - safe can be a boolean or integer, defaults to `0`. If `1`, the program will issue a cmd `getlasterror` to server to query the result. If `false`, return value `n` would always be `-1`

####n, err = col:update_all(queries, ordered, writeConcern)
Batch update, returns update result document as described in mongo docs. (Only usable in 2.6+)

 - queries should be structured as {{ q = {}, u = {}, upsert = <boolean>, multi = <boolean>}} where q is the selector, u is the update, and upsert and multi are identical to normal update.
 - ordered, if true, tells the server to execute the operations in the order they are given in the list. If false, the database is free to parallelize the operations but does not guarantee order.
 - writeConcern is a write concern document {w=<number>, j=<boolean>, etc}

####n, err = col:aggregate(pipeline)
Aggregation. Returns a result document. See mongo aggregation db command docs for more info.

 - pipeline is an ordered list of aggregation pipeline functions.

####n, err = col:insert(docs, continue_on_error, safe)
Returns 0 for success, or nil with error message.

 - continue_on_error, if set, the database will not stop processing a bulk insert if one fails (eg due to duplicate IDs).
 - safe can be a boolean or integer, defaults to `0` or `false`. If `1` or ``true`, the program will issue a cmd `getlasterror` to server to query the result. If `false`, return value `n` would always be `-1`

####n, err = col:delete(selector, singleRemove, safe)
Returns number of rows been deleted, or nil with error message.

 - singleRemove if set to 1, the database will remove only the first matching document in the collection. Otherwise all matching documents will be removed. Default to `0`
 - safe can be a boolean or integer, defaults to `0`. If `1`, the program will issue a cmd `getlasterror` to server to query the result. If `false`, return value `n` would always be `-1`

####r = col:find_one(query, returnfields)
Returns a single element array, or nil.

 - returnfields is the fields to return, eg: `{n=0}` or `{n=1}`

####cursor = col:find(query, returnfields, num_each_query)
Returns a cursor object for excuting query.

 - returnfields is the fields to return, eg: `{n=0}` or `{n=1}`
 - num_each_query is the max result number for each query of the cursor to avoid fetch a large result in memory, must larger than `1`, `0` for no limit, default to `100`.

####col:getmore(cursorID, [numberToReturn], [offset_i])
 - cursorID is an 8 byte string representing the cursor to getmore on
 - numberToReturn is the number of results to return, defaults to -1
 - offset_i is the number to start numbering the returned table from, defaults to 1

####col:kill_cursors(cursorIDs)

###Cursor objects
--------------------

####index, item = cursor:next()
Returns the next item and advances the cursor.

####cursor:pairs()
A handy wrapper around cursor:next() that works in a generic for loop:

		for index, item in cursor:pairs() do

####cursor:limit(n)
Limits the number of results returned.

####result = cursor:sort(field, size)
Returns an array with size `size` sorted by given field. 

 - field is an array by which to sort, and this array size _MUST be 1_. The element in the array has as key the field name, and as value either `1` for ascending sort, or `-1` for descending sort. 
 - num is the temp array size for sorting, default to `10000`.

###Object id
-------------------

####objid:tostring()
####objid:get_ts()
####objid:get_pid()
####objid:get_hostname()
####objid:get_inc()

###Grid FS Object
-------------------

_under developing_

####gridfs_file = gridfs:find_one(fields)
Returns a gridfs file object.

####gridfs_file = gridfs:find(fields)
Returns a list of gridfs file objects.

####gridfs_file = gridfs:remove(fields, continue_on_err, safe)
Returns number of files been deleted, or nil with error message.

 - singleRemove if set to 1, the database will remove only the first matching document in the collection. Otherwise all matching documents will be removed. Default to `0`
 - safe can be a boolean or integer, defaults to `0`. If `1`, the program will issue a cmd `getlasterror` to server to query the result. If `false`, return value `n` would always be `-1`

####bool = gridfs:get(file_handler, fields)
Writes first object matchs fields into file_handler. This API will malloc a buffer in file size in memory.

####n, err = gridfs:insert(file_handler, meta, safe)
Returns 0 for success, or nil with error message.

 - file_handler is file handler returned by io:open().
 - meta is a table include `_id, filename, chunkSize, contentType, aliases, metadata` or anything the user wants to store. Default meta.filename is the object id in string.
 - safe can be a boolean or integer, defaults to `0`. If `1`, the program will issue a cmd `getlasterror` to server to query the result. If `false`, return value `n` would always be `-1`

####gridfs_file, err = gridfs:new(meta)
Returns a new gridfs file object, or nil with error message.

 - meta is a table include `_id, filename, chunkSize, contentType, aliases, metadata` or anything the user wants to store. Default meta.filename is the object id in string.


###Grid FS File Object
-------------------

####n, err = gridfs_file:read(size, offset)
Returns number of bytes read from mongodb, or nil with error message.

 - offse start from 0

####n, err = gridfs_file:write(buf, offset, size)
Returns number of bytes writen into mongodb, or nil with error message.

 - offset is the file offset(should not beyond the end of the file), starting from 0.
 - size is the number of bytes to be writen.

####gridfs_file:flush()
Flushes cached data in memory to the database. Should always be called at the end of a file write.

####bool, err = gridfs_file:update_md5()
Hashs the file content and updates the md5 in file collection.

Notes
---------------------------
 - collections are string containing any value except "\0"
 - database_name are strings containing any character except "." and "\0"

Known Issues
---------------------------
1. Auth bson message has reduntant value.
2. Could not inserting a null array, it always inserted as a document.
3. Gridfs_new api only create a meta info in file_col.

Example
---------------------------
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000)
            ok, err = conn:connect()
            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle ( "test" )
            col = db:get_col("test")

            r = col:find_one({name="dog"})
            ngx.say(r["name"])

For Test Case
--------------------
#####mongo config:
    > config = {_id: 'testset', members: [
              {_id: 0, host: '10.6.2.51:27017'},
              {_id: 1, host: '10.6.2.51:27018'},
              {_id: 2, host: '10.6.2.51:27019'}]
        }
    > rs.initiate(config);

#####start-mongo.sh:
        nohup bin/mongod --dbpath=/data/57cbd36d-5b70-4888-8537-bea71119363e/mongodb --oplogSize 10 --rest --replSet testset --port 27017 --keyFile key.file &
        nohup bin/mongod --dbpath=/data/0a9419ae-4ec3-48c2-ad8d-df68a09aed13/mongodb --oplogSize 10 --rest --replSet testset --port 27018 --keyFile key.file &
        nohup bin/mongod --dbpath=/data/8ee9efc0-a854-4c45-8893-7b4cb9ed0e5f/mongodb --oplogSize 10 --rest --replSet testset --port 27019 --keyFile key.file &

#####mongo user:
    > use test
    > db.addUser("admin","admin")
