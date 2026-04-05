local voltic = require("voltic")

voltic.register({
    name = "base",
    prefix = "b2",
    description = "Base converter",
})

local function to_base(n, base)
    if n == 0 then return "0" end
    local negative = n < 0
    n = math.abs(n)
    local digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    local result = {}
    while n > 0 do
        local d = n % base
        result[#result + 1] = digits:sub(d + 1, d + 1)
        n = math.floor(n / base)
    end
    -- Reverse
    local reversed = {}
    for i = #result, 1, -1 do
        reversed[#reversed + 1] = result[i]
    end
    local s = table.concat(reversed)
    if negative then s = "-" .. s end
    return s
end

local function from_base(str, base)
    str = str:lower()
    if str:sub(1,1) == "-" then
        local n = from_base(str:sub(2), base)
        if n then return -n end
        return nil
    end
    local digits = "0123456789abcdefghijklmnopqrstuvwxyz"
    local result = 0
    for i = 1, #str do
        local c = str:sub(i, i)
        local d = digits:find(c, 1, true)
        if not d or d - 1 >= base then return nil end
        result = result * base + (d - 1)
    end
    return result
end

-- Detect base from prefix or content
local function detect_and_parse(s)
    s = s:match("^%s*(.-)%s*$") or s
    -- Remove underscores used for readability (e.g., 1_000_000)
    s = s:gsub("_", "")

    if s:match("^%-?0x[%x]+$") or s:match("^%-?0X[%x]+$") then
        local v = s:gsub("0[xX]", "")
        return from_base(v, 16), 16
    end
    if s:match("^%-?0b[01]+$") or s:match("^%-?0B[01]+$") then
        local v = s:gsub("0[bB]", "")
        return from_base(v, 2), 2
    end
    if s:match("^%-?0o[0-7]+$") or s:match("^%-?0O[0-7]+$") then
        local v = s:gsub("0[oO]", "")
        return from_base(v, 8), 8
    end
    -- Plain decimal
    if s:match("^%-?%d+$") then
        return tonumber(s), 10
    end
    -- Try hex without prefix (if it has a-f chars)
    if s:match("^%-?[%x]+$") and s:match("[a-fA-F]") then
        return from_base(s, 16), 16
    end
    -- Fall back: assume decimal if parses
    local n = tonumber(s)
    if n then return math.floor(n), 10 end
    return nil, nil
end

-- Parse explicit base syntax: "ff hex" | "101 bin" | "255 dec"
local function parse_explicit(q)
    local num, base_name = q:match("^(%S+)%s+(%a+)$")
    if not num then return nil end
    local base_map = {
        bin = 2, binary = 2, b = 2,
        oct = 8, octal = 8, o = 8,
        dec = 10, decimal = 10, d = 10,
        hex = 16, hexadecimal = 16, h = 16, x = 16,
    }
    local base = base_map[base_name:lower()]
    if not base then return nil end
    return from_base(num:gsub("_", ""), base), base
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query

    if query == "" then
        return {
            voltic.result({
                id = "hint",
                name = "Type a number to convert between bases",
                description = "b2 255 | b2 0xff | b2 0b1010 | b2 ff hex",
                score = 100,
            }),
        }
    end

    -- Try explicit "n base" first
    local value, src_base = parse_explicit(query)
    if not value then
        value, src_base = detect_and_parse(query)
    end

    if not value then
        return {
            voltic.result({
                id = "invalid",
                name = "Can't parse: " .. query,
                description = "Try: 255 | 0xff | 0b1010 | 0o17 | ff hex",
                score = 100,
            }),
        }
    end

    local results = {}
    local bases = {
        { n = 10, name = "DEC", fmt = function(v) return tostring(v) end },
        { n = 16, name = "HEX", fmt = function(v) return "0x" .. to_base(v, 16) end },
        { n = 2, name = "BIN", fmt = function(v) return "0b" .. to_base(v, 2) end },
        { n = 8, name = "OCT", fmt = function(v) return "0o" .. to_base(v, 8) end },
    }

    for i, b in ipairs(bases) do
        local s = b.fmt(value)
        local is_src = (b.n == src_base)
        results[#results + 1] = voltic.result({
            id = "base_" .. b.n,
            name = s,
            description = b.name .. (is_src and " (input)" or ""),
            score = 300 - i,
            meta = { value = s },
        })
    end

    -- ASCII character (if printable)
    if value >= 32 and value <= 126 then
        results[#results + 1] = voltic.result({
            id = "ascii",
            name = "'" .. string.char(value) .. "'",
            description = "ASCII character",
            score = 250,
            meta = { value = string.char(value) },
        })
    end

    -- Bit width info
    if value >= 0 then
        local bits = 0
        local v = value
        while v > 0 do bits = bits + 1; v = math.floor(v / 2) end
        if bits == 0 then bits = 1 end
        local bytes = math.ceil(bits / 8)
        results[#results + 1] = voltic.result({
            id = "bits",
            name = bits .. " bits, " .. bytes .. " byte" .. (bytes == 1 and "" or "s"),
            description = "Width needed to represent this value",
            score = 200,
            meta = { value = tostring(bits) },
        })
    end

    return results
end

function on_action(result, action)
    if result.meta and result.meta.value then
        return "copy:" .. result.meta.value
    end
end

function on_actions(result)
    if result.meta and result.meta.value then
        return {{ key = "RET", label = "copy" }}
    end
    return {{ key = "RET", label = "select" }}
end
