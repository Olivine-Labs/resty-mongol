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

=== TEST 1: insert use colmt
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
            col = db:get_col("test")

            col:delete({name="dog"})
            col:insert({{name="dog"}})
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
dog
--- no_error_log
[error]


=== TEST 2: insert use dbmt
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
            local col = "test" 

            db:delete(col, {name="dog"})
            db:insert(col, {{name="dog"}})
            r = db:find(col, {name="dog"})

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
dog
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
--- ONLY
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

