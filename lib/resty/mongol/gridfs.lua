local mod_name = (...):match ( "^(.*)%..-$" )

local md5 = require "resty.md5"
local str = require "resty.string"
local bson = require ( mod_name .. ".bson" )
local object_id = require ( mod_name .. ".object_id" )

local gridfs_mt = { }
local gridfs = { __index = gridfs_mt }
local get_bin_data = bson.get_bin_data
local get_utc_date = bson.get_utc_date

function gridfs_mt:insert(fh, meta, safe)
    if not meta then meta = {} end

    if not meta.chunkSize then
        meta.chunkSize = 256*1024
    end

    local id
    if meta._id then
        id = meta._id
    else
        meta._id = object_id.new()
    end
    if not meta.filename then
        meta.filename = meta._id:tostring()
    end

    local n = 0
    local length = 0
    local r, err 
    local md5_obj = md5:new()
    while true do
        local bytes = fh:read(meta.chunkSize)
        if not bytes then break end

        md5_obj:update(bytes)
        r, err = self.chunk_col:insert({{ files_id = meta._id,
                                n = n,
                                data = get_bin_data(bytes),
                                }}, nil, safe)
        if safe and not r then return nil, err end

        n = n + 1
        length = length + string.len(bytes)
    end
    local md5hex = str.to_hex(md5_obj:final())

    meta.md5 = md5hex
    meta.uploadDate = get_utc_date(ngx.time() * 1000)
    meta.length = length
    r, err = self.file_col:insert({meta}, nil, safe)
    if safe and not r then return nil, err end
    return r
end

return gridfs
