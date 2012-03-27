lua-resty-mongol - Lua Mongodb driver for ngx_lua base on the cosocket API
===========================

Thanks to project Mongol by daurnimator

License is MIT/X11

Dependancies
---------------------------

luajit

lua-md5

[ngx_lua 0.5.0rc5](https://github.com/chaoslawful/lua-nginx-module/tags) or [ngx_openresty 1.0.11.7](http://openresty.org/#Download) is required.


Installation
---------------------------

		make install

Usage
---------------------------

Functions will generally raise errors if something unexpected happens

Requring the module will return a function that connects to mongod:
it takes a host (default localhost) and a port (default 27017);
it returns a connection object.

		mongol = require "mongol"
		conn = mongol ( ) -- Connect to localhost:27017

###Connection objects have server wide methods.

####conn:cmd ( database_name , query , [collection] )
Returns the document
or `nil , errmsg , return_document , responseFlags` on failure;
where `responseFlags` is a table containing the fields `CursorNotFound, QueryFailure, ShardConfigStale, AwaitCapable`.

####bool , hosts = conn:ismaster ( )
Returns a boolean indicating if this is the master server and a table of other hosts this server is replicating with.

####newconn = conn:getprimary ( [already_checked] )
Returns a new connection object that is connected to the primary server
or `nil , errmsg` on failure.

The returned connection object may be this connection object itself.


####databases = conn:databases ( )
Returns a table describing databases on the server.

		databases.name: string
		databases.empty: boolean
		databases.sizeOnDisk: number

####conn:shutdown ( )
Shutsdown the server. Returns nothing.

####db = conn:new_db_handle ( database_name )
Returns a database object

###Database objects perform actions on a database

####db:list ( )
####db:dropDatabase ( )
####db:add_user ( username , password )
####db:auth ( username , password )
####db:count ( collection , query )
####db:drop ( collection )
####db:update ( collection , selector , update , upsert , multiupdate )
####db:insert ( collection , docs , continue_on_error )
####db:delete ( collection , selector , SingleRemove )
####db:kill_cursors ( collection , cursorIDs )
####db:query ( collection , query , returnfields , numberToSkip , numberToReturn , options )
####db:getmore ( collection , cursorID , [numberToReturn] , [offset_i] )
 - cursorID is an 8 byte string representing the cursor to getmore on
 - numberToReturn is the number of results to return, defaults to -1
 - offset_i is the number to start numbering the returned table from, defaults to 1

####cursor = db:find ( collection , query , returnfields )

###Cursor objects
####index , item = cursor:next ( )
Returns the next item and advances the cursor

####cursor:pairs ( )
A handy wrapper around cursor:next() that works in a generic for loop:
		for index , item in cursor:pairs() do

Notes
---------------------------
 - collections are string containing any value except "\0"
 - database_name are strings containing any character except "." and "\0"

TL;DR
---------------------------
		local mongol = require "mongol"
		local conn = mongol ( ) -- Connect to localhost:27017
		local db = conn:new_db_handle ( "mydatabase" )

		assert ( db:auth ( "username" , "password" ) )

		for i , v in db:find ( "mycollection" , { foo = "bar" } ):pairs() do
			print ( v )
		end
