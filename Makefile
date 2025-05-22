.PHONY: install test clean

install:
	luarocks make

test:
	lua tests/test_nvim_config_compare.lua

clean:
	rm -rf output/

lint:
	luacheck lua/ bin/

dev-install:
	luarocks make --local

all: test install
