local dkjson = require("dkjson")
local M = {}

function M.is_valid_utf8(str)
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


function M.sanitize(val, visited)
  visited = visited or {}
  local t = type(val)
  if t == "string" then
    return M.is_valid_utf8(val) and val or "<invalid utf8 string>"
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
        sanitized_v = M.sanitize(v, visited)
      elseif type(v) == "string" then
        sanitized_v = M.is_valid_utf8(v) and v or "<invalid utf8 string>"
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


local function sanitize_functions_and_metatables(str)
    str = str:gsub("<function%s*%d+>", "[\"<function>\"]")
    str = str:gsub('%= %["<function>"%]', '= "<function>"')
    str = str:gsub(', %["<function>"%]', ', "<function>"')
    str = str:gsub('%{ %["<function>"%]', '{ "<function>"')
    str = str:gsub("<metatable>", "[\"<metatable>\"]")
    return str
end

-- Extract all <n>{ ... } "named tables" and record their string bodies
local function extract_named_tables(str, named_tables)
  named_tables = named_tables or {}
  local pattern = "<(%d+)>%s*{"
  local result = ""
  local last_end = 1

  while true do
    local s, e, n = str:find(pattern, last_end)
    if not s then break end
    local body_start = e
    local i = body_start
    local level = 1
    while level > 0 and i < #str do
      i = i + 1
      local c = str:sub(i, i)
      if c == '{' then
        level = level + 1
      elseif c == '}' then
        level = level - 1
      end
    end
    if level ~= 0 then
      error("Unmatched braces while extracting named table <"..n..">")
    end
    local body_end = i
    local tbl_body = str:sub(body_start, body_end)
    extract_named_tables(tbl_body, named_tables)
    named_tables[tonumber(n)] = tbl_body
    result = result .. str:sub(last_end, s-1) .. '"__VIMINSPECT_TABLE_' .. n .. '__"'
    last_end = body_end + 1
  end

  result = result .. str:sub(last_end)
  return result, named_tables
end


local function replace_table_refs(str, named_tables)
  return str:gsub("<table%s*(%d+)>", function(n)
    if named_tables[tonumber(n)] then
      return '"__VIMINSPECT_TABLE_' .. n .. '__"'
    else
      return '<table ' .. n ..'>'
    end
  end)
end

local function deep_resolve_placeholders(val, table_objs)
  if type(val) ~= "table" then return val end

  -- Check if this is an array-like table (all integer keys 1..n)
  local is_array = true
  local n = 0
  for k, _ in pairs(val) do
    if type(k) ~= "number" or k <= 0 or math.floor(k) ~= k then
      is_array = false
      break
    end
    if k > n then n = k end
  end

  if is_array then
    local arr = {}
    for i = 1, n do
      local v = val[i]
      if type(v) == "string" then
        local m = v:match("^__VIMINSPECT_TABLE_(%d+)__$")
        if m then
          m = tonumber(m)
          if table_objs[m] == nil and table_objs.__bodies[m] then
            local chunk, err = load("return " .. table_objs.__bodies[m], "viminspect_table_body", "t", {})
            assert(chunk, "Parse error in named table " .. m .. ": " .. err)
            local ok, tval = pcall(chunk)
            assert(ok, "Eval error in named table " .. m .. ": " .. tval)
            table_objs[m] = tval
            deep_resolve_placeholders(tval, table_objs)
          end
          arr[i] = table_objs[m] or false -- keep a false value rather than nil
        elseif v == "nil" then
          arr[i] = false
        else
          arr[i] = v
        end
      elseif type(v) == "table" then
        arr[i] = deep_resolve_placeholders(v, table_objs)
      else
        arr[i] = v
      end
    end
    -- Replace original table contents with array
    for k in pairs(val) do val[k] = nil end
    for i = 1, n do val[i] = arr[i] end
    return val
  else
    -- hash table: process recursively
    for k, v in pairs(val) do
      if type(v) == "string" then
        local m = v:match("^__VIMINSPECT_TABLE_(%d+)__$")
        if m then
          m = tonumber(m)
          if table_objs[m] == nil and table_objs.__bodies[m] then
            local chunk, err = load("return " .. table_objs.__bodies[m], "viminspect_table_body", "t", {})
            assert(chunk, "Parse error in named table " .. m .. ": " .. err)
            local ok, tval = pcall(chunk)
            assert(ok, "Eval error in named table " .. m .. ": " .. tval)
            table_objs[m] = tval
            deep_resolve_placeholders(tval, table_objs)
          end
          val[k] = table_objs[m] or false
        elseif v == "nil" then
          val[k] = false
        else
          val[k] = v
        end
      elseif type(v) == "table" then
        val[k] = deep_resolve_placeholders(v, table_objs)
      end
    end
    return val
  end
end

function M.parse_viminspect_string(viminspect_str)
    -- Remove <function ...> and <metatable>
    local sanitized = sanitize_functions_and_metatables(viminspect_str)
    -- Extract named tables, replace with placeholders
    local without_named, named_bodies = extract_named_tables(sanitized)
    -- Replace <table n> with placeholder
    without_named = replace_table_refs(without_named, named_bodies)
    local chunk, err = load("return " .. without_named, "viminspect_table", "t", {})
    if not chunk then error("Parse error: " .. err) end
    local ok, tbl = pcall(chunk)
    if not ok then error("Eval error: " .. tbl) end
    -- Parse all named table bodies into tables (with their own placeholders)
    local table_objs = { __bodies = named_bodies }
    for n, body in pairs(named_bodies) do
        -- Recursively parse each table body
        local tchunk, terr = load("return " .. body, "viminspect_table_body", "t", {})
        if tchunk then
            local tok, tval = pcall(tchunk)
            if tok then
                table_objs[n] = tval
            else
                table_objs[n] = {}
            end
        else
            table_objs[n] = {}
        end
    end
    -- Now resolve all table references recursively in main table and in all named tables
    tbl = deep_resolve_placeholders(tbl, table_objs)
    return tbl
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
  plugins = M.parse_viminspect_string(vim.inspect(plugins))

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
