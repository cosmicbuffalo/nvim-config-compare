.PHONY: install test clean

install:
	luarocks make

test:
	busted tests/

clean:
	rm -rf output/

lint:
	luacheck lua/ bin/

dev-install:
	luarocks make --local

all: test install
