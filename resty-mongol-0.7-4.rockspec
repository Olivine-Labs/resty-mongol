package = "resty-mongol"
version = "0.7-4"
source = {
  url = "https://github.com/Olivine-Labs/resty-mongol/archive/v0.7.tar.gz",
  dir = "resty-mongol-0.7"
}
description = {
  summary = "Mongo driver for openresty.",
  detailed = [[
  ]],
  homepage = "",
  license = "MIT <http://opensource.org/licenses/MIT>"
}
dependencies = {
  "lua >= 5.1",
  "luacrypto >= 0.3.2"
}
build = {
  type = "builtin",
  modules = {
    ["resty-mongol.init"]       = "src/init.lua",
    ["resty-mongol.colmt"]      = "src/colmt.lua",
    ["resty-mongol.cursor"]     = "src/cursor.lua",
    ["resty-mongol.dbmt"]       = "src/dbmt.lua",
    ["resty-mongol.get"]        = "src/get.lua",
    ["resty-mongol.gridfs"]     = "src/gridfs.lua",
    ["resty-mongol.gridfs_file"]= "src/gridfs_file.lua",
    ["resty-mongol.ll"]         = "src/ll.lua",
    ["resty-mongol.misc"]       = "src/misc.lua",
    ["resty-mongol.object_id"]  = "src/object_id.lua",
    ["resty-mongol.bson"]       = "src/bson.lua",
  }
}
