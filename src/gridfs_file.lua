local mod_name = (...):match ( "^(.*)%..-$" )

local md5 = require "crypto".digest
local bson = require ( mod_name .. ".bson" )

local gridfs_file_mt = { }
local gridfs_file = { __index = gridfs_file_mt }
local get_bin_data = bson.get_bin_data

function gridfs_file_mt:discard()
  self.chunk_cache = {}
  self.chunk_cache_num = 0
end

--write any cached data to mongo
function gridfs_file_mt:flush()
  if self.chunk_cache_num > 0 then
    local updates = {}
    for n, v in pairs(self.chunk_cache) do
      updates[#updates+1] = {
        q = {
          files_id = self.files_id,
          n = n
        },
        u = {
          ['$set'] = {data = get_bin_data(v.data)}
        },
        upsert = true,
        multi = false
      }
    end
    self:discard()
    local r, err = self.chunk_col:update_all(updates, false, {w = "majority"})
    if not r and safe then return nil,"write failed: "..err end
    local r, err = self.file_col:update(
    {
      _id = self.files_id
    },
    {
      ['$set'] = {
        length = self.file_size,
        md5 = 0
      }
    },
    0, 0, false)
    if not r and safe then return nil,"write failed: "..err end
  end
  return true
end

function gridfs_file_mt:get_chunk(n)
  local od = self.chunk_cache[n]
  if not od then
    od = self.chunk_col:find_one({files_id = self.files_id, n = n})
    if not od or not od.data then
      od = {
        data = ""
      }
    end
    self:set_chunk(n, od.data)
  end
  return od
end

function gridfs_file_mt:set_chunk(n, data)
  local chunk = self.chunk_cache[n]
  if not chunk then
    if self.chunk_cache_num >= self.chunk_cache_max then
      self:flush()
    end

    chunk = {}
    self.chunk_cache[n] = chunk
    self.chunk_cache_num = self.chunk_cache_num + 1
  end
  chunk.data = data
end

-- write size bytes from the buf string into mongo, by the offset 
function gridfs_file_mt:write(buf, offset, size, safe)
  size = size or string.len(buf)
  if offset > self.file_size then return nil, "invalid offset" end
  if size > #buf then return nil, "invalid size" end

  local cn        -- number of chunks to be updated
  local af        -- number of bytes to be updated in first chunk
  local bn = 0    -- bytes number of buf already updated
  local nv = {}
  local od, t, i, r, err
  local of = offset % self.chunk_size
  local n = math.floor(offset/self.chunk_size)

  --if write size matches up to chunk size
  if of == 0 and size % self.chunk_size == 0 then
    cn = size/self.chunk_size
    for i = 1, cn do
      self:set_chunk(n+i-1, string.sub(buf, self.chunk_size*(i-1) + 1, self.chunk_size*(i-1) + self.chunk_size))
    end
    bn = size
  else

    if of + size > self.chunk_size then
      --               chunk1 chunk2 chunk3
      -- old data      ====== ====== ======
      -- write buf        =======
      --               ...     -> of
      --                  ...  -> af
      af = self.chunk_size - of
    else
      af = size
    end

    cn = math.ceil((size + offset)/self.chunk_size) - n
    for i = 1, cn do
      if i == 1 then
        od = self:get_chunk(n+i-1)
        if of ~= 0 and od then
          if size + of >= self.chunk_size then
            --               chunk1 chunk2 chunk3
            -- old data      ====== ====== ======
            -- write buf        =====
            t = string.sub(od.data, 1, of) 
            .. string.sub(buf, 1, af)
          else
            --               chunk1 chunk2 chunk3
            -- old data      ====== ====== ======
            -- write buf        ==
            t = string.sub(od.data, 1, of) 
            .. string.sub(buf, 1, af)
            .. string.sub(od.data, size + of + 1)
          end
          bn = af
        elseif of == 0 and od then
          if size < self.chunk_size then
            --               chunk1 chunk2 chunk3
            -- old data      ====== ====== ======
            -- write buf     ===
            t = string.sub(buf, 1) 
            .. string.sub(od.data, size + 1)
            bn = bn + size
          else
            --               chunk1 chunk2 chunk3
            -- old data      ====== ====== ======
            -- write buf     =========
            t = string.sub(buf, 1, self.chunk_size)
            bn = bn + self.chunk_size
          end
        else
          t = string.sub(buf, 1, self.chunk_size)
          bn = bn + #t --self.chunk_size
        end
      elseif i == cn then
        od = self:get_chunk(n+i-1)
        if od then
          t = string.sub(buf, bn + 1, size) 
          .. string.sub(od.data, size - bn + 1)
        else
          t = string.sub(buf, bn + 1, size) 
        end
        bn = size
      else
        t = string.sub(buf, bn + 1, bn + self.chunk_size)
        bn = bn + self.chunk_size
      end
      self:set_chunk(n+i-1, t)
    end
  end

  if offset + size > self.file_size then
    self.file_size = size + offset
  end
  return bn
end

-- read size bytes from mongo by the offset
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
    r = self:get_chunk(n)
    if not r then return nil, "read chunk failed" end
    if size - rn < self.chunk_size then
      bytes = bytes .. string.sub(r.data, 1, size - rn)
      rn = size
    else
      bytes = bytes .. r.data
      rn = rn + self.chunk_size
    end
    n = n + 1
    if rn >= size then break end
  end
  return bytes
end

function gridfs_file_mt:update_md5()
  local n = math.floor(self.file_size/self.chunk_size)
  local md5_obj = md5.new("md5")
  local r, i, err

  for i = 0, n do
    r = self:get_chunk(i)
    if not r then return false, "read chunk failed" end

    md5_obj:update(r.data)
  end
  local md5hex = md5_obj:final()

  self.file_md5 = md5hex
  r,err = self.file_col:update(
  {
    _id = self.files_id
  },
  {
    ['$set'] = {md5 = md5hex}
  }, 0, 0, true)
  if not r then return false, "update failed: "..err end
  return true
end

return gridfs_file
