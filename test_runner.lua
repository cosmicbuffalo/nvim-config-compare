#!/usr/bin/env lua

-- Add the current directory to the package path
package.path = "./lua/?.lua;" .. package.path
package.path = "./?.lua;" .. package.path

-- Run the tests
require("tests.test_nvim_config_compare")
