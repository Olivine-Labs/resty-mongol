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

=== TEST 1: insert
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            local conn = mongo("10.6.2.51")

            conn:set_timeout(1000) -- 1 sec
            --local ok, err = conn:set_keepalive() -- 1 sec
            --if not ok then
            --    ngx.say("failed to set keepalive: ", err)
            --    return
            --end

            local db = conn:new_db_handle ( "test" )
            col = db:get_col("test")

            col:delete({name="dog"})
            col:insert({{name="dog"}})
            r = col:find({name="dog"})

            for i , v in r:pairs() do
                if v["name"] then
                    ngx.say(v["name"])
                end
            end
        ';
    }
--- request
GET /t
--- response_body
dog
--- no_error_log
[error]

