#!/usr/bin/env lua

-- Add the current directory to the package path
package.path = "./lua/?.lua;" .. package.path
package.path = "./?.lua;" .. package.path
package.path = package.path .. ";./lua/?.lua"

-- Run the tests with busted from local installation
local command = "~/.luarocks/bin/busted -p '_spec%.lua$' tests/"
os.execute(command)
