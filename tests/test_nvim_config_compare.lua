local lu = require("luaunit")
local nvim_config_compare = require("nvim_config_compare")

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

-- Run the tests
os.exit(lu.LuaUnit.run())
