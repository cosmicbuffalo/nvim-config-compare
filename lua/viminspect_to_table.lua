--[[
This module parses a vim.inspect string, including references like <1>{}, <table 1>, etc,
returning a Lua table with references resolved (deep copies if necessary).
Caveat: cycles and shared references will become deep copies.

Usage:
    local viminspect_to_table = require("viminspect_to_table")
    local tbl = viminspect_to_table.parse(viminspect_str)
]]

local M = {}

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

local function print_line(s, n)
    local i = 1
    for line in s:gmatch("([^\n]*)\n?") do
        if i == n then
            print(line)
            break
        end
        i = i + 1
    end
end

function M.parse(viminspect_str)
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

return M
