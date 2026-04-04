local voltic = require("voltic")

voltic.register({
    name = "hash",
    prefix = "hh",
    description = "Hash, encode & decode text",
})

-- Base64 alphabet
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function base64_encode(data)
    local result = {}
    local pad = ""
    local s = data

    -- Pad with zeros
    local mod3 = #s % 3
    if mod3 > 0 then
        pad = string.rep("=", 3 - mod3)
        s = s .. string.rep("\0", 3 - mod3)
    end

    for i = 1, #s, 3 do
        local a, b, c = s:byte(i, i + 2)
        local n = a * 65536 + b * 256 + c
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64
        result[#result + 1] = b64chars:sub(c1 + 1, c1 + 1)
            .. b64chars:sub(c2 + 1, c2 + 1)
            .. b64chars:sub(c3 + 1, c3 + 1)
            .. b64chars:sub(c4 + 1, c4 + 1)
    end

    local encoded = table.concat(result)
    if #pad > 0 then
        encoded = encoded:sub(1, #encoded - #pad) .. pad
    end
    return encoded
end

local function base64_decode(data)
    local s = data:gsub("=", "")
    local result = {}

    local lookup = {}
    for i = 1, #b64chars do
        lookup[b64chars:sub(i, i)] = i - 1
    end

    local buffer = 0
    local bits = 0
    for i = 1, #s do
        local ch = s:sub(i, i)
        local val = lookup[ch]
        if val then
            buffer = buffer * 64 + val
            bits = bits + 6
            if bits >= 8 then
                bits = bits - 8
                local byte = math.floor(buffer / (2 ^ bits)) % 256
                result[#result + 1] = string.char(byte)
                buffer = buffer % (2 ^ bits)
            end
        end
    end
    return table.concat(result)
end

local function url_encode(str)
    local result = str:gsub("([^%w%-_.~])", function(c)
        return string.format("%%%02X", c:byte())
    end)
    return result
end

local function url_decode(str)
    local result = str:gsub("%%(%x%x)", function(hex)
        return string.char(tonumber(hex, 16))
    end)
    return result:gsub("+", " ")
end

local function to_hex(str)
    local result = {}
    for i = 1, #str do
        result[#result + 1] = string.format("%02x", str:byte(i))
    end
    return table.concat(result)
end

local function string_hash(str)
    -- Simple DJB2 hash (not crypto-grade, but useful for quick hashing)
    local hash = 5381
    for i = 1, #str do
        hash = ((hash * 33) + str:byte(i)) % (2 ^ 32)
    end
    return string.format("%08x", hash)
end

local function char_count(str)
    return tostring(#str) .. " chars, " .. tostring(#str:gsub("[^\n]", "")) .. " lines"
end

function on_search(query)
    if query == "" then
        return {
            voltic.result({
                id = "hint",
                name = "Type text to hash/encode",
                description = "base64, url encode, hex, hash, length",
                score = 100,
            }),
        }
    end

    local results = {}

    -- Base64 encode
    results[#results + 1] = voltic.result({
        id = "b64enc",
        name = base64_encode(query),
        description = "Base64 Encode",
        score = 200,
        meta = { value = base64_encode(query) },
    })

    -- Base64 decode (try it, might fail on invalid input)
    local ok_dec, decoded = pcall(base64_decode, query)
    if ok_dec and decoded and #decoded > 0 then
        -- Check if it looks like valid decoded text
        local printable = true
        for i = 1, math.min(#decoded, 100) do
            local b = decoded:byte(i)
            if b < 32 and b ~= 10 and b ~= 13 and b ~= 9 then
                printable = false
                break
            end
        end
        if printable then
            results[#results + 1] = voltic.result({
                id = "b64dec",
                name = decoded,
                description = "Base64 Decode",
                score = 150,
                meta = { value = decoded },
            })
        end
    end

    -- URL encode
    results[#results + 1] = voltic.result({
        id = "urlenc",
        name = url_encode(query),
        description = "URL Encode",
        score = 180,
        meta = { value = url_encode(query) },
    })

    -- URL decode
    local url_decoded = url_decode(query)
    if url_decoded ~= query then
        results[#results + 1] = voltic.result({
            id = "urldec",
            name = url_decoded,
            description = "URL Decode",
            score = 170,
            meta = { value = url_decoded },
        })
    end

    -- Hex
    results[#results + 1] = voltic.result({
        id = "hex",
        name = to_hex(query),
        description = "Hex",
        score = 160,
        meta = { value = to_hex(query) },
    })

    -- Hash (DJB2)
    results[#results + 1] = voltic.result({
        id = "hash",
        name = string_hash(query),
        description = "DJB2 Hash",
        score = 140,
        meta = { value = string_hash(query) },
    })

    -- Character count
    results[#results + 1] = voltic.result({
        id = "len",
        name = char_count(query),
        description = "Length",
        score = 120,
        meta = { value = char_count(query) },
    })

    return results
end

function on_action(result, action)
    if action == "default" or action == "copy" then
        local value = result.meta and result.meta.value or result.name
        return "copy:" .. value
    end
end

function on_actions(result)
    return {
        { key = "RET", label = "copy to clipboard" },
    }
end
