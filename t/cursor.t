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
$ENV{TEST_NGINX_TIMEOUT} = 10000;

no_long_string();
#no_diff();

run_tests();

__DATA__

=== TEST 1: cursor limit
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty-mongol"
            conn = mongo()
            conn:set_timeout(10000) 
            local ok, err = conn:connect("127.0.0.1")

            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r = db:auth("admin", "admin")
            if not r then ngx.say("auth failed") end
            local col = db:get_col("test")

            r, err = col:delete({}, nil, true)
            if not r then ngx.say("delete failed: "..err) end

            local i, j
            local t = {}
            for i = 1,10 do
                j = 100 - i
                table.insert(t, {name="dog",n=i,m=j})
            end
            r, err = col:insert(t, nil, true)
            if not r then ngx.say("insert failed: "..err) end

            r = col:find({name="dog"})
            r:limit(3)
            for i , v in r:pairs() do
                ngx.say(v["n"])
            end

            r = col:find({name="dog"}, nil, 0)
            r:limit(3)
            for i , v in r:pairs() do
                ngx.say(v["n"])
            end

            r = col:find({name="dog"}, nil, 2)
            r:limit(5)
            for i , v in r:pairs() do
                ngx.say(v["n"])
            end
            conn:close()
        ';
    }
--- request
GET /t
--- response_body
1
2
3
1
2
3
1
2
3
4
5
--- no_error_log
[error]

=== TEST 2: cursor sort
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty-mongol"
            conn = mongo()
            conn:set_timeout(10000) 
            local ok, err = conn:connect("127.0.0.1")

            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r = db:auth("admin", "admin")
            if not r then ngx.say("auth failed") end
            local col = db:get_col("test")

            r, err = col:delete({}, nil, true)
            if not r then ngx.say("delete failed: "..err) end

            local i, j
            local t = {}
            for i = 1,10 do
                j = 10 - i
                table.insert(t, {name="dog",n=i,m=j})
            end
            r, err = col:insert(t, nil, true)
            if not r then ngx.say("insert failed: "..err) end

            r = col:find({name="dog"})
            r:limit(5)
            r:sort({n=-1})
            for i , v in r:pairs() do
                ngx.say(v["n"])
            end

            r = col:find({name="dog"})
            r:limit(5)
            r:sort({n=1})
            for i , v in r:pairs() do
                ngx.say(v["n"])
            end

            r = col:find({name="dog"})
            r:limit(3)
            r:sort({n=-1})
            for i , v in r:pairs() do
                ngx.say(v["n"])
            end

            r = col:find({name="dog"})
            r:limit(3)
            r:sort({n=1})
            for i , v in r:pairs() do
                ngx.say(v["n"])
            end

            conn:close()
        ';
    }
--- request
GET /t
--- response_body
10
9
8
7
6
1
2
3
4
5
10
9
8
1
2
3
--- no_error_log
[error]

=== TEST 3: cursor sort after next
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty-mongol"
            conn = mongo()
            conn:set_timeout(10000) 
            local ok, err = conn:connect("127.0.0.1")

            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r = db:auth("admin", "admin")
            if not r then ngx.say("auth failed") end
            local col = db:get_col("test")

            r, err = col:delete({}, nil, true)
            if not r then ngx.say("delete failed: "..err) end

            local i, j
            local t = {}
            for i = 1,10 do
                j = 10 - i
                --r, err = col:insert({{name="dog",n=i,m=j}}, nil, true)
                --if not r then ngx.say("insert failed: "..err) end
                table.insert(t, {name="dog",n=i,m=j})
            end
            r, err = col:insert(t, nil, true)
            if not r then ngx.say("insert failed: "..err) end

            r = col:find({name="dog"}, nil, 5)
            r:limit(5)
            for k,v in r:pairs() do
                ngx.say(v["n"])
                break
            end

            r:sort({n=1})
            for i , v in r:pairs() do
                ngx.say(v["n"])
            end

            conn:close()
        ';
    }
--- timeout: 50
--- request
GET /t
--- response_body
1
2
3
4
5
--- no_error_log
[error]

=== TEST 4: cursor next over limit
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty-mongol"
            conn = mongo()
            conn:set_timeout(10000) 
            local ok, err = conn:connect("127.0.0.1")

            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r = db:auth("admin", "admin")
            if not r then ngx.say("auth failed") end
            local col = db:get_col("test")

            r, err = col:delete({}, nil, true)
            if not r then ngx.say("delete failed: "..err) end

            local i, j
            local t = {}
            for i = 1,10 do
                j = 100 - i
                table.insert(t, {name="dog",n=i,m=j})
            end
            r, err = col:insert(t, nil, true)
            if not r then ngx.say("insert failed: "..err) end

            r = col:find({name="dog"})
            r:limit(3)
            for i , v in r:pairs() do
                ngx.say(v["n"])
            end

            k,v = r:next()
            ngx.say(v)

            r = col:find({name="dog"})
            for i = 1, 10 do
                k,v = r:next()
                ngx.say(v["n"])
            end

            i,v = r:next()
            ngx.say(v)

            conn:close()
        ';
    }
--- request
GET /t
--- response_body
1
2
3
nil
1
2
3
4
5
6
7
8
9
10
nil
--- no_error_log
[error]

=== TEST 5: cursor skip
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty-mongol"
            conn = mongo()
            conn:set_timeout(10000)
            local ok, err = conn:connect("127.0.0.1")

            if not ok then
                ngx.say("connect failed: "..err)
            end

            local db = conn:new_db_handle("test")
            local r = db:auth("admin", "admin")
            if not r then ngx.say("auth failed") end
            local col = db:get_col("test")

            r, err = col:delete({}, nil, true)
            if not r then ngx.say("delete failed: "..err) end

            local i, j
            local t = {}
            for i = 1,200 do
                j = 10 - i
                table.insert(t, {name="dog",n=i,m=j})
            end
            r, err = col:insert(t, nil, true)
            if not r then ngx.say("insert failed: "..err) end

            r = col:find({name="dog"})
            r:limit(5)
            r:skip(5)
            r:sort({n=-1})
            for i , v in r:pairs() do
                ngx.say(i .. ": " .. v["n"])
            end

            r = col:find({name="dog"})
            r:limit(5)
            r:skip(5)
            r:sort({n=1})
            for i , v in r:pairs() do
                ngx.say(i .. ": " .. v["n"])
            end

            r = col:find({name="dog"}, nil, 2)
            r:limit(3)
            r:skip(50)
            r:sort({n=-1})
            for i , v in r:pairs() do
                ngx.say(i .. ": " .. v["n"])
            end

            r = col:find({name="dog"}, nil, 2)
            r:limit(3)
            r:skip(50)
            r:sort({n=1})
            for i , v in r:pairs() do
                ngx.say(i .. ": " .. v["n"])
            end

            conn:close()
        ';
    }
--- request
GET /t
--- response_body
1: 195
2: 194
3: 193
4: 192
5: 191
1: 6
2: 7
3: 8
4: 9
5: 10
1: 150
2: 149
3: 148
1: 51
2: 52
3: 53
--- no_error_log
[error]
