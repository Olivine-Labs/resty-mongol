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


=== TEST 1: write chunk < 1, offset = 0
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

            r, err = fs:remove({}, nil, true)
            if not r then ngx.say("delete failed: "..err) end

            local f,err = io.open("t/servroot/html/test.txt", "rb")
            if not f then ngx.say("fs open failed: "..err) ngx.exit(ngx.HTTP_OK) end

            r, err = fs:insert(f, {chunkSize = 6, filename="testfile"}, true)
            if not r then ngx.say("fs insert failed: "..err) end
            ngx.say(r)
            io.close(f)

            local gf = fs:find_one({filename="testfile"})
            gf:write("abc", 0)

            f = io.open("/tmp/testfile", "wb")
            r = fs:get(f, {filename="testfile"})
            if not r then ngx.say("get file failed: "..err) end
            io.close(f)

        ';
    }
--- user_files
>>> test.txt
11111111111111111111
--- request
GET /t
--- response_body
0
--- no_error_log
--- output_files
>>> /tmp/testfile 
abc11111111111111111
--- no_error_log
[error]

=== TEST 2: write chunk < 1, offset > 0
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

            r, err = fs:remove({}, nil, true)
            if not r then ngx.say("delete failed: "..err) end

            local f,err = io.open("t/servroot/html/test.txt", "rb")
            if not f then ngx.say("fs open failed: "..err) ngx.exit(ngx.HTTP_OK) end

            r, err = fs:insert(f, {chunkSize = 6, filename="testfile"}, true)
            if not r then ngx.say("fs insert failed: "..err) end
            ngx.say(r)
            io.close(f)

            local gf = fs:find_one({filename="testfile"})
            gf:write("abc", 2)

            f = io.open("/tmp/testfile", "wb")
            r = fs:get(f, {filename="testfile"})
            if not r then ngx.say("get file failed: "..err) end
            io.close(f)

        ';
    }
--- user_files
>>> test.txt
11111111111111111111
--- request
GET /t
--- response_body
0
--- no_error_log
--- output_files
>>> /tmp/testfile 
11abc111111111111111
--- no_error_log
[error]

=== TEST 4: write chunk = 2, offset = 0
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

            r, err = fs:remove({}, nil, true)
            if not r then ngx.say("delete failed: "..err) end

            local f,err = io.open("t/servroot/html/test.txt", "rb")
            if not f then ngx.say("fs open failed: "..err) ngx.exit(ngx.HTTP_OK) end

            r, err = fs:insert(f, {chunkSize = 6, filename="testfile"}, true)
            if not r then ngx.say("fs insert failed: "..err) end
            ngx.say(r)
            io.close(f)

            local gf = fs:find_one({filename="testfile"})
            gf:write("abcabcdefdef", 0)

            f = io.open("/tmp/testfile", "wb")
            r = fs:get(f, {filename="testfile"})
            if not r then ngx.say("get file failed: "..err) end
            io.close(f)

        ';
    }
--- user_files
>>> test.txt
11111111111111111111
--- request
GET /t
--- response_body
0
--- no_error_log
--- output_files
>>> /tmp/testfile 
abcabcdefdef11111111
--- no_error_log
[error]

=== TEST 5: write chunk > 1, offset = 0
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

            r, err = fs:remove({}, nil, true)
            if not r then ngx.say("delete failed: "..err) end

            local f,err = io.open("t/servroot/html/test.txt", "rb")
            if not f then ngx.say("fs open failed: "..err) ngx.exit(ngx.HTTP_OK) end

            r, err = fs:insert(f, {chunkSize = 6, filename="testfile"}, true)
            if not r then ngx.say("fs insert failed: "..err) end
            ngx.say(r)
            io.close(f)

            local gf = fs:find_one({filename="testfile"})
            gf:write("abcabcdef", 0)

            f = io.open("/tmp/testfile", "wb")
            r = fs:get(f, {filename="testfile"})
            if not r then ngx.say("get file failed: "..err) end
            io.close(f)

        ';
    }
--- user_files
>>> test.txt
11111111111111111111
--- request
GET /t
--- response_body
0
--- no_error_log
--- output_files
>>> /tmp/testfile 
abcabcdef11111111111
--- no_error_log
[error]

