local lu = require("luaunit")
-- Try different ways to require the module
local nvim_config_compare

-- Try multiple paths to find the module
local paths_to_try = {
  "nvim_config_compare",
  "lua.nvim_config_compare",
  "./lua/nvim_config_compare"
}

local success = false
for _, path in ipairs(paths_to_try) do
  success = pcall(function() 
    nvim_config_compare = require(path)
  end)
  if success then break end
end

if not success then
  error("Could not load nvim_config_compare module. Make sure it's in your LUA_PATH.")
end

TestNvimConfigCompare = {}

function TestNvimConfigCompare:test_parse_viminspect_string()
  local test_str = [[<1>{a = 1, b = "test", c = <table 2>}]]
  local result = nvim_config_compare.parse_viminspect_string(test_str)
  lu.assertIsTable(result)
  lu.assertEquals(result.a, 1)
  lu.assertEquals(result.b, "test")
end

function TestNvimConfigCompare:test_sanitize()
  local test_table = {
    a = 1,
    b = "test",
    c = function() end,
    d = {
      e = "nested",
      f = function() end
    }
  }
  
  local sanitized = nvim_config_compare.sanitize(test_table)
  lu.assertIsTable(sanitized)
  lu.assertEquals(sanitized.a, 1)
  lu.assertEquals(sanitized.b, "test")
  lu.assertEquals(sanitized.c, "<function>")
  lu.assertIsTable(sanitized.d)
  lu.assertEquals(sanitized.d.e, "nested")
  lu.assertEquals(sanitized.d.f, "<function>")
end

function TestNvimConfigCompare:test_is_valid_utf8()
  lu.assertTrue(nvim_config_compare.is_valid_utf8("Hello world"))
  lu.assertTrue(nvim_config_compare.is_valid_utf8("こんにちは"))
  lu.assertTrue(nvim_config_compare.is_valid_utf8("🚀"))
  
  -- Create an invalid UTF-8 string
  local invalid_utf8 = string.char(0xC0, 0xAF)
  lu.assertFalse(nvim_config_compare.is_valid_utf8(invalid_utf8))
end

-- Run the tests
if not package.loaded['busted'] then
  os.exit(lu.LuaUnit.run())
end
