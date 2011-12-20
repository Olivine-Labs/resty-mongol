LUA = lua -e"package.path = package.path .. ';./?/init.lua'"
LUA_SHAREDIR = $(DESTDIR)/usr/share/lua/5.1

.PHONY: install test

install:
	install -d $(LUA_SHAREDIR)/mongol
	install -m644 mongol/* $(LUA_SHAREDIR)/mongol

test:
	$(LUA) test/test.lua
	$(LUA) test/test_bson.lua
