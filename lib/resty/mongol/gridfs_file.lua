local mod_name = (...):match ( "^(.*)%..-$" )

local md5 = require "resty.md5"
local str = require "resty.string"
local bson = require ( mod_name .. ".bson" )
local object_id = require ( mod_name .. ".object_id" )

local gridfs_file_mt = { }
local gridfs_file = { __index = gridfs_file_mt }
local get_bin_data = bson.get_bin_data
local get_utc_date = bson.get_utc_date

function gridfs_file_mt:read(size, offset)
    size = size or self.file_size
    if size < 0 then
        return nil, "invalid size"
    end
    offset = offset or 0
    if offset < 0 or offset >= self.file_size then
        return nil, "invalid offset"
    end

    local n = math.floor(offset / self.chunk_size)
    local r
    local bytes = ""
    local rn = 0
    while true do
        r = self.chunk_col:find_one({files_id = self.files_id, n = n})
        if not r then return nil, "read chunk failed" end
        if size - rn < self.chunk_size then
            bytes = bytes .. string.sub(r.data, 1, size - rn)
        else
            bytes = bytes .. r.data
        end
        rn = rn + string.len(bytes)
        n = n + 1
        if rn >= size then break end
    end
    return bytes
end

return gridfs_file
