# vim:set ft= ts=4 sw=4 et:

use Test::Nginx::Socket;
use Cwd qw(cwd);

repeat_each(2);

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

=== TEST 1: set and get
--- http_config eval: $::HttpConfig
--- config
    location /t {
        content_by_lua '
            local mongo = require "resty.mongol"
            local conn = mongo("10.6.2.51")

            --red:set_timeout(1000) -- 1 sec

            local db = conn:new_db_handle ( "test" )
            col = "test"
            db:delete(col, {name="dog"} )
            db:insert(col, {{name="dog"}})
            r = db:find(col, {name="dog"})

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

