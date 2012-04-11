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
            local fs = db:get_gridfs("fs")

            --r, err = col:delete({}, nil, true)
            --if not r then ngx.say("delete failed: "..err) end

            local f,err = io.open("/tmp/nginx.conf", "rb")
            if not f then ngx.say("fs open failed: "..err) ngx.exit(ngx.HTTP_OK) end
            r, err = fs:insert(f, nil, true)
            if not r then ngx.say("fs insert failed: "..err) end
            ngx.say(r)
            io.close(f)

            local f,err = io.open("/tmp/nginx.conf", "rb")
            r, err = fs:insert(f, nil, false)
            if not r then ngx.say("fs insert failed: "..err) end
            ngx.say(r)
            io.close(f)

        ';
    }
--- request
GET /t
--- response_body
0
-1
--- no_error_log
[error]

