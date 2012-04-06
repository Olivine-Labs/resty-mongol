# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(1);

plan tests => repeat_each() * (3 * blocks());

my $pwd = cwd();

our $HttpConfig = qq{
    lua_package_path "$pwd/lib/?/init.lua;;";
};

$ENV{TEST_NGINX_RESOLVER} = '8.8.8.8';
$ENV{TEST_NGINX_MONGO_PORT} ||= 27017;

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: col insert 
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(10000) 
            ok, err = conn:connect("10.6.2.51")

            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local col = db:get_col("test")

            local r,err = col:insert({{name="dog",n=10,m=20}}, nil, true)
            if not r then ngx.say("insert failed: "..err) end

            r = db:auth("admin", "admin")
            if not r then ngx.say("auth failed") end

            r, err = col:delete({}, nil, true)
            if not r then ngx.say("delete failed: "..err) end

            r, err = col:insert({{name="dog",n=10,m=20}, {name="cat"}}, 
                        nil, true)
            if not r then ngx.say("insert failed: "..err) end
            ngx.say(r)

            r = col:find({name="dog"})

            for i , v in r:pairs() do
                if v["name"] then
                    ngx.say(v["name"])
                end
            end
            conn:close()
        ';
    }
--- request
GET /t
--- response_body
insert failed: unauthorized
0
dog
--- no_error_log
[error]

=== TEST 2: db auth failed
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r,err = db:auth("admin", "pass")
            if not r then ngx.say(err) 
            else
                ngx.say(r)
            end
        ';
    }
--- request
GET /t
--- response_body
auth fails
--- no_error_log
[error]

=== TEST 3: socket failed
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 
            ok, err = conn:connect("10.6.2.51", 27016)

            if not ok then
                ngx.say("connect failed: "..err)
            end
        ';
    }
--- request
GET /t
--- response_body
connect failed: connection refused
--- error_log
[error]

=== TEST 4: socket reuse
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end
            ngx.say(conn:get_reused_times())

            ok, err = conn:set_keepalive()
            if not ok then
                ngx.say("set keepalive failed: "..err)
            end

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end
            ngx.say(conn:get_reused_times())
        ';
    }
--- request
GET /t
--- response_body
0
1
--- no_error_log
[error]

=== TEST 5: is master
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end

            r, h = conn:ismaster()
            if not r then
                ngx.say("query master failed: "..h)
            end

            ngx.say(r)
            for i,v in pairs(h) do
                ngx.say(v)
            end
            conn:close()
        ';
    }
--- request
GET /t
--- response_body_like
true
--- no_error_log
[error]

=== TEST 6: is not master
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51", 27018)
            if not ok then
                ngx.say("connect failed: "..err)
            end

            r, h = conn:ismaster()
            if r == nil then
                ngx.say("query master failed: "..h)
            end

            ngx.say(r)
            for i,v in pairs(h) do
                ngx.say(v)
            end
            conn:close()
        ';
    }
--- request
GET /t
--- response_body_like
false
--- no_error_log
[error]

=== TEST 7: get primary
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51", 27018)
            if not ok then
                ngx.say("connect failed: "..err)
            end

            r, h = conn:ismaster()
            if r == nil then
                ngx.say("query master failed: "..h)
            end

            if r then ngx.say("already master") return end

            newconn,err = conn:getprimary()
            if not newconn then
                ngx.say("get primary failed: "..err)
            end
            r, h = newconn:ismaster()
            if not r then
                ngx.say("get master failed")
            end

            ngx.say("get primary")
            conn:close()
        ';
    }
--- request
GET /t
--- response_body
get primary
--- no_error_log
[error]

=== TEST 8: db auth
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r,err = db:auth("admin", "admin")
            if not r then ngx.say("auth failed") end
            ngx.say(r)
        ';
    }
--- request
GET /t
--- response_body
1
--- no_error_log
[error]

=== TEST 9: col count
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r = db:auth("admin", "admin")
            if not r then
                ngx.say("auth failed")
                ngx.exit(ngx.OK)
            end
            col = db:get_col("test")

            col:delete({name="sheep"})
            col:insert({{name="sheep"}})
            local n, err = col:count({name="sheep"})
            if not n then
                ngx.say("count fail: "..err)
            end
            ngx.say(n)
        ';
    }
--- request
GET /t
--- response_body
1
--- no_error_log
[error]

=== TEST 10: col update and with $inc
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            local r, err = conn:connect("10.6.2.51")
            if not r then ngx.say("connect failed: "..err) end

            local db = conn:new_db_handle("test")
            local col = db:get_col("test")
            r,err = col:update({name="dog"},{name="cat"}, nil, nil, true)
            if not r then ngx.say("update failed: "..err) end

            r = db:auth("admin", "admin")
            if not r then ngx.say("auth failed") end

            r,err = col:delete({})
            if not r then ngx.say("delete failed: "..err) end

            r,err = col:insert({{name="dog"}})
            if not r then ngx.say("insert failed: "..err) end

            r,err = col:update({name="dog"},{name="cat"}, nil, nil, true)
            if not r then ngx.say("update failed: "..err) end
            ngx.say(r)

            r = col:find({name="cat"})
            for i , v in r:pairs() do
                if v["name"] then
                    ngx.say(v["name"])
                end
            end

            r,err = col:update({name="sheep"},{name="cat"}, 1, nil, true)
            if not r then ngx.say("update failed: "..err) end
            ngx.say(r)

            r,err = col:update({name="sheep"},{name="cat"}, nil, nil, true)
            if not r then ngx.say("update failed: "..err) end
            ngx.say(r)


            col:insert({{name="dog",n=1}})

            local update = {}
            update["$inc"] = {n=1}
            r,err = col:update({name="dog"},update, nil, nil, true)
            if not r then ngx.say("update failed: "..err) end
            ngx.say(r)

            r = col:find({name="dog"})
            for i , v in r:pairs() do
                if v["n"] then
                    ngx.say(v["n"])
                end
            end

            col:insert({{name="dog",n=10}})
            r,err = col:update({name="dog"}, update, nil, 1, true)
            if not r then ngx.say("update failed: "..err) end
            ngx.say(r)
        ';
    }
--- request
GET /t
--- response_body
update failed: unauthorized
1
cat
1
0
1
2
2
--- no_error_log
[error]

=== TEST 11: col find with limit(getmore)
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r = db:auth("admin", "admin")
            if not r then
                ngx.say("auth failed")
                ngx.exit(ngx.OK)
            end

            col = db:get_col("test")
            col:delete({name="puppy"})

            for i = 1, 10 do
                col:insert({{name="puppy"}})
            end

            r = col:find({name="puppy"}, nil, 4)
            local j = 0
            for i , v in r:pairs() do
                j = j +1
            end

            ngx.say(j)
        ';
    }
--- request
GET /t
--- response_body
10
--- no_error_log
[error]

=== TEST 12: col find with field
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r = db:auth("admin", "admin")
            if not r then
                ngx.say("auth failed")
                ngx.exit(ngx.OK)
            end

            col = db:get_col("test")
            col:delete({name="puppy"})

            for i = 1, 3 do
                col:insert({{name="puppy", n=i, m="foo"}})
            end

            r = col:find({name="puppy"}, {n=0}, 4)
            for i , v in r:pairs() do
                ngx.say(v["n"])
                ngx.say(v["name"])
            end

            r = col:find({name="puppy"}, {n=1}, 4)
            for i , v in r:pairs() do
                ngx.say(v["n"])
                ngx.say(v["name"])
            end
        ';
    }
--- request
GET /t
--- response_body
nil
puppy
nil
puppy
nil
puppy
1
nil
2
nil
3
nil
--- no_error_log
[error]

=== TEST 13: col drop
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(1000) 

            ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r = db:auth("admin", "admin")
            if not r then
                ngx.say("auth failed")
                ngx.exit(ngx.OK)
            end

            col = db:get_col("test")
            col:insert({{name="puppy", n=i, m="foo"}})
            local r,err = col:drop()

            if not r then
                ngx.say(err)
            else
                ngx.say(r)
            end

            local r ,err = col:drop()
            if not r then
                ngx.say(err)
            else
                ngx.say(r)
            end
        ';
    }
--- request
GET /t
--- response_body
1
ns not found
--- no_error_log
[error]

=== TEST 14: col find_one
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(10000) 

            local ok, err = conn:connect("10.6.2.51",27017)
            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r = db:auth("admin", "admin")
            if not r then
                ngx.say("auth failed")
                ngx.exit(ngx.HTTP_OK)
            end

            local col = db:get_col("test")
            r,err = col:delete({})
            if not r then
                ngx.say("delete failed: "..err)
                ngx.exit(ngx.HTTP_OK)
            end

            col:insert({{name="puppy", n=1, m="foo"}})
            col:insert({{name="puppy", n=2, m="foo"}})

            r = col:find_one({name="puppy"}, {n=1})
            if not r then
                ngx.say("not found")
            end
            ngx.say(r["n"]) 

            r = col:find_one({name="puppy"}, {n=0})
            if not r then
                ngx.say("not found")
            end
            ngx.say(r["n"]) 

            r = col:find_one({name="p"})
            if not r then
                ngx.say("not found")
            end
        ';
    }
--- request
GET /t
--- response_body
1
nil
not found
--- no_error_log
[error]

=== TEST 15: col delete safe 
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(10000) 

            local ok, err = conn:connect("10.6.2.51")
            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")

            local col = db:get_col("test")
            r,err = col:delete({}, nil, 1)
            if not r then
                ngx.say("delete failed: "..err)
            end

            local r = db:auth("admin", "admin")
            if not r then
                ngx.say("auth failed")
                ngx.exit(ngx.HTTP_OK)
            end

            r,err = col:delete({})
            col:insert({{name="puppy", n=1, m="foo"}})
            col:insert({{name="puppy", n=1, m="foo"}})
            col:insert({{name="puppy", n=2, m="foo"}})
            r = col:delete({name="puppy"}, 0, 1)

            if not r then
                ngx.say("delete failed: "..err)
                ngx.exit(ngx.HTTP_OK)
            end
            ngx.say(r)

            col:insert({{name="puppy", n=1, m="foo"}})
            col:insert({{name="puppy", n=1, m="foo"}})
            col:insert({{name="puppy", n=2, m="foo"}})
            r = col:delete({name="puppy"}, 1, true)

            if not r then
                ngx.say("delete failed: "..err)
                ngx.exit(ngx.HTTP_OK)
            end
            ngx.say(r)

            col:insert({{name="puppy", n=1, m="foo"}})
            col:insert({{name="puppy", n=1, m="foo"}})
            col:insert({{name="puppy", n=2, m="foo"}})
            r = col:delete({name="puppy"}, 1, false)

            if not r then
                ngx.say("delete failed: "..err)
                ngx.exit(ngx.HTTP_OK)
            end
            ngx.say(r)
        ';
    }
--- request
GET /t
--- response_body
delete failed: unauthorized
3
1
-1
--- no_error_log
[error]

