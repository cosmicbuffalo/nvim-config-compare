local M = {}
local dkjson = require("dkjson")

-- Strict UTF-8 validator
local function is_valid_utf8(str)
  if type(str) ~= "string" then return false end
  local i, len = 1, #str
  while i <= len do
    local c = str:byte(i)
    if c < 0x80 then
      i = i + 1
    elseif c >= 0xC2 and c <= 0xDF and i + 1 <= len then
      local c2 = str:byte(i + 1)
      if c2 < 0x80 or c2 > 0xBF then return false end
      i = i + 2
    elseif c == 0xE0 and i + 2 <= len then
      local c2, c3 = str:byte(i + 1), str:byte(i + 2)
      if c2 < 0xA0 or c2 > 0xBF or c3 < 0x80 or c3 > 0xBF then return false end
      i = i + 3
    elseif ((c >= 0xE1 and c <= 0xEC) or c == 0xEE or c == 0xEF) and i + 2 <= len then
      local c2, c3 = str:byte(i + 1), str:byte(i + 2)
      if c2 < 0x80 or c2 > 0xBF or c3 < 0x80 or c3 > 0xBF then return false end
      i = i + 3
    elseif c == 0xED and i + 2 <= len then
      local c2, c3 = str:byte(i + 1), str:byte(i + 2)
      if c2 < 0x80 or c2 > 0x9F or c3 < 0x80 or c3 > 0xBF then return false end
      i = i + 3
    elseif c == 0xF0 and i + 3 <= len then
      local c2, c3, c4 = str:byte(i + 1), str:byte(i + 2), str:byte(i + 3)
      if c2 < 0x90 or c2 > 0xBF or c3 < 0x80 or c3 > 0xBF or c4 < 0x80 or c4 > 0xBF then return false end
      i = i + 4
    elseif (c >= 0xF1 and c <= 0xF3) and i + 3 <= len then
      local c2, c3, c4 = str:byte(i + 1), str:byte(i + 2), str:byte(i + 3)
      if c2 < 0x80 or c2 > 0xBF or c3 < 0x80 or c3 > 0xBF or c4 < 0x80 or c4 > 0xBF then return false end
      i = i + 4
    elseif c == 0xF4 and i + 3 <= len then
      local c2, c3, c4 = str:byte(i + 1), str:byte(i + 2), str:byte(i + 3)
      if c2 < 0x80 or c2 > 0x8F or c3 < 0x80 or c3 > 0xBF or c4 < 0x80 or c4 > 0xBF then return false end
      i = i + 4
    else
      return false
    end
  end
  return true
end

local function sanitize(val, visited)
  visited = visited or {}
  local t = type(val)
  if t == "string" then
    return is_valid_utf8(val) and val or "<invalid utf8 string>"
  elseif t == "number" or t == "boolean" or val == nil then
    return val
  elseif t == "table" then
    if visited[val] then
      return "<circular reference>"
    end
    visited[val] = true
    local result = {}
    for k, v in pairs(val) do
      -- Only keep string/number keys for JSON
      local ok_key = type(k) == "string" or type(k) == "number"
      local sanitized_v
      if type(v) == "function" then
        sanitized_v = "<function>"
      elseif type(v) == "userdata" then
        sanitized_v = "<userdata>"
      elseif type(v) == "thread" then
        sanitized_v = "<thread>"
      elseif type(v) == "table" then
        sanitized_v = sanitize(v, visited)
      elseif type(v) == "string" then
        sanitized_v = is_valid_utf8(v) and v or "<invalid utf8 string>"
      else
        sanitized_v = v
      end
      if ok_key then
        result[k] = sanitized_v
      end
    end
    return result
  else
    return "<" .. t .. ">"
  end
end

function M.dump(path)
  -- Gather options
  local opts = {}
  for k, _ in pairs(vim.api.nvim_get_all_options_info()) do
    local ok, val = pcall(function() return vim.o[k] end)
    if ok then opts[k] = val end
  end
  -- Gather autocommands
  local aucmds = vim.api.nvim_exec2("autocmd", { output = true }).output
  -- Gather keymaps
  local modes = { "n", "i", "v", "x", "s", "o", "c", "t" }
  local keymaps = {}
  for _, mode in ipairs(modes) do
    local ok, res = pcall(vim.api.nvim_get_keymap, mode)
    if ok then
      local sanitized_mode_maps = {}
      for i, map in ipairs(res) do
        sanitized_mode_maps[i] = sanitize(map)
      end
      keymaps[mode] = sanitized_mode_maps
    else
      keymaps[mode] = {}
    end
  end
  -- Gather plugins
  local plugins = require("lazy.core.config").spec.plugins
  local viminspect_to_table = require("viminspect_to_table")
  plugins = viminspect_to_table.parse(vim.inspect(plugins))

  local result = {
    options = opts,
    autocommands = aucmds,
    keymaps = keymaps,
    plugins = plugins,
  }

  local json = dkjson.encode(result, { indent = true })

  if path then
    local file = io.open(path, "w")
    if not file then
      print("ERROR: Cannot open file for writing: " .. path)
      return
    end
    file:write(json)
    file:close()
  else
    print(json)
  end
end

return M
