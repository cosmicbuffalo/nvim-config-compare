local nvim_config_compare = require("nvim_config_compare")

describe("nvim_config_compare", function()
  describe("parse_viminspect_string", function()
    it("should parse a viminspect string with table references", function()
      local test_str = [[{a = 1, b = "test", c = <2>{ d = 'd' }, e = <table 2> }]]
      local result = nvim_config_compare.parse_viminspect_string(test_str)
      
      assert.is_table(result)
      assert.equal(1, result.a)
      assert.equal("test", result.b)
      assert.is_table(result.c)
      assert.equal("d", result.c.d)
      assert.equal("d", result.e.d)
    end)
  end)

  describe("sanitize", function()
    it("should sanitize a table with functions and nested tables", function()
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
      assert.is_table(sanitized)
      assert.equal(1, sanitized.a)
      assert.equal("test", sanitized.b)
      assert.equal("<function>", sanitized.c)
      assert.is_table(sanitized.d)
      assert.equal("nested", sanitized.d.e)
      assert.equal("<function>", sanitized.d.f)
    end)
  end)

  describe("is_valid_utf8", function()
    it("should validate UTF-8 strings correctly", function()
      assert.is_true(nvim_config_compare.is_valid_utf8("Hello world"))
      assert.is_true(nvim_config_compare.is_valid_utf8("こんにちは"))
      assert.is_true(nvim_config_compare.is_valid_utf8("🚀"))
      
      -- Create an invalid UTF-8 string
      local invalid_utf8 = string.char(0xC0, 0xAF)
      assert.is_false(nvim_config_compare.is_valid_utf8(invalid_utf8))
    end)
  end)
end)
