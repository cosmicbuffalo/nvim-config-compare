#!/usr/bin/env lua

-- Add the current directory to the package path
package.path = "./lua/?.lua;" .. package.path
package.path = "./?.lua;" .. package.path
package.path = package.path .. ";./lua/?.lua"

-- Run the tests
dofile("tests/test_nvim_config_compare.lua")
