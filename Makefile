OPENRESTY_PREFIX=/usr/local/openresty
LUA = lua -e"package.path = package.path .. ';./?/init.lua'"
LUA_SHAREDIR = $(DESTDIR)/usr/share/lua/5.1

.PHONY: install test

install:
	install -d $(LUA_SHAREDIR)/mongol
	install -m644 mongol/* $(LUA_SHAREDIR)/mongol

test:
	PATH=$(OPENRESTY_PREFIX)/nginx/sbin:$$PATH prove -I../test-nginx/lib -r t
