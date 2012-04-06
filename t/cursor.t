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
            local mongo = require "resty.mongol"
            conn = mongo:new()
            conn:set_timeout(10000) 
            local ok, err = conn:connect("10.6.2.51")

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

