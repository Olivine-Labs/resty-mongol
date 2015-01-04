export PATH := $(PWD)/t/build/sbin:$(PWD)/t/build/bin:$(PWD)/t/build/nginx/sbin:$(PWD)/t/build/luajit/bin:$(PATH)
export PERL5LIB := $(PWD)/t/build/lib/perl5

OPENRESTY=ngx_openresty-1.7.7.1
OPENRESTY_URL=http://openresty.org/download/$(OPENRESTY).tar.gz

LUAROCKS=luarocks-2.0.13
LUAROCKS_URL=http://luarocks.org/releases/$(LUAROCKS).tar.gz

clean:
	rm -rf t/build t/servroot t/tmp

prepare: t/build/lib/perl5 t/build/bin/resty t/build/luajit/bin/luarocks

test: prepare
	# Install resty-mongol via luarocks so the dependencies are fetched and we
	# can reference it by the "lua-rocks" name.
	find $(PWD)/t/build/luajit -type d -name "*resty-mongol*" -exec rm -rf {} +
	env PATH=$(PATH) luarocks install $(PWD)/resty-mongol-0.8-4.rockspec
	# Installing via luarocks above doesn't actually seem to install our local
	# copy of the files. Ideally it would, but as a workaround, install the
	# current version being tested manually.
	rm -r $(PWD)/t/build/luajit/share/lua/5.1/resty-mongol
	cp -r $(PWD)/src $(PWD)/t/build/luajit/share/lua/5.1/resty-mongol
	# Run the wrapper script that starts and stops mongo.
	env PATH=$(PATH) PERL5LIB=$(PERL5LIB) t/prove

t/tmp:
	mkdir -p $@
	touch $@

t/tmp/cpanm: | t/tmp
	curl -o $@ -L http://cpanmin.us
	chmod +x $@
	touch $@

t/build/lib/perl5: t/tmp/cpanm
	$< -L t/build --notest Test::Nginx
	touch $@

t/tmp/$(OPENRESTY).tar.gz: | t/tmp
	curl -o $@ $(OPENRESTY_URL)

t/tmp/$(OPENRESTY): t/tmp/$(OPENRESTY).tar.gz
	tar -C t/tmp -xf $<
	touch $@

t/tmp/$(OPENRESTY)/Makefile: | t/tmp/$(OPENRESTY)
	cd t/tmp/$(OPENRESTY) && ./configure --prefix=$(PWD)/t/build --with-debug

t/build/bin/resty: t/tmp/$(OPENRESTY)/Makefile
	cd t/tmp/$(OPENRESTY) && make && make install

t/tmp/$(LUAROCKS).tar.gz: | t/tmp
	curl -o $@ $(LUAROCKS_URL)

t/tmp/$(LUAROCKS): t/tmp/$(LUAROCKS).tar.gz
	tar -C t/tmp -xf $<
	touch $@

t/tmp/$(LUAROCKS)/config.unix: | t/tmp/$(LUAROCKS)
	cd t/tmp/$(LUAROCKS) && ./configure \
		--prefix=$(PWD)/t/build/luajit \
		--with-lua=$(PWD)/t/build/luajit \
		--lua-suffix=jit-2.1.0-alpha \
		--with-lua-include=$(PWD)/t/build/luajit/include/luajit-2.1

t/build/luajit/bin/luarocks: t/tmp/$(LUAROCKS)/config.unix
	cd t/tmp/$(LUAROCKS) && make && make install
