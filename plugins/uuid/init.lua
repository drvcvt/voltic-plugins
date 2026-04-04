local voltic = require("voltic")

voltic.register({
    name = "uuid",
    prefix = "uu",
    description = "UUID & random string generator",
})

-- Seed the RNG. We don't have os.time(), but math.randomseed accepts any number.
-- Use a combination of collectgarbage-less heuristics: tostring of tables produces
-- unique addresses, which we can hash into a seed.
local function seed_rng()
    local t = {}
    local addr = tostring(t):match("0x(%x+)")
    local seed = tonumber(addr, 16) or 12345
    -- Mix in a second allocation for more entropy
    local t2 = {}
    local addr2 = tostring(t2):match("0x(%x+)")
    seed = seed + (tonumber(addr2, 16) or 67890)
    math.randomseed(seed)
    -- Burn a few values to improve distribution
    for _ = 1, 10 do math.random() end
end

seed_rng()

local hex_chars = "0123456789abcdef"

local function random_hex(length)
    local result = {}
    for i = 1, length do
        local idx = math.random(1, 16)
        result[i] = hex_chars:sub(idx, idx)
    end
    return table.concat(result)
end

local function uuid_v4()
    -- Format: xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx
    -- where y is one of 8, 9, a, b
    local parts = {
        random_hex(8),
        random_hex(4),
        "4" .. random_hex(3),
        hex_chars:sub(math.random(9, 12), math.random(9, 12)) .. random_hex(3),
        random_hex(12),
    }
    return parts[1] .. "-" .. parts[2] .. "-" .. parts[3] .. "-" .. parts[4] .. "-" .. parts[5]
end

-- Base64 alphabet
local b64chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"

local function random_base64(byte_length)
    -- Generate random bytes, then base64 encode
    local bytes = {}
    for i = 1, byte_length do
        bytes[i] = math.random(0, 255)
    end

    local result = {}
    local i = 1
    while i <= #bytes do
        local a = bytes[i] or 0
        local b = bytes[i + 1] or 0
        local c = bytes[i + 2] or 0

        local n = a * 65536 + b * 256 + c
        local c1 = math.floor(n / 262144) % 64
        local c2 = math.floor(n / 4096) % 64
        local c3 = math.floor(n / 64) % 64
        local c4 = n % 64

        result[#result + 1] = b64chars:sub(c1 + 1, c1 + 1)
        result[#result + 1] = b64chars:sub(c2 + 1, c2 + 1)

        if i + 1 <= #bytes then
            result[#result + 1] = b64chars:sub(c3 + 1, c3 + 1)
        else
            result[#result + 1] = "="
        end

        if i + 2 <= #bytes then
            result[#result + 1] = b64chars:sub(c4 + 1, c4 + 1)
        else
            result[#result + 1] = "="
        end

        i = i + 3
    end

    return table.concat(result)
end

local function random_alphanumeric(length)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
    local result = {}
    for i = 1, length do
        local idx = math.random(1, #chars)
        result[i] = chars:sub(idx, idx)
    end
    return table.concat(result)
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query -- trim

    -- Default: generate 1 UUID
    if query == "" then
        -- Re-seed for fresh randomness each search
        seed_rng()

        local id = uuid_v4()
        return {
            voltic.result({
                id = "uuid_1",
                name = id,
                description = "UUID v4 -- press Enter to copy",
                score = 300,
                meta = { value = id },
            }),
            voltic.result({
                id = "hint",
                name = "More: uu 5 | uu hex 16 | uu base64 32 | uu alnum 20",
                description = "Generate multiple UUIDs or random strings",
                score = 100,
            }),
        }
    end

    seed_rng()

    -- "hex <length>" -> random hex string
    local hex_len = query:match("^hex%s+(%d+)$")
    if hex_len then
        hex_len = math.min(tonumber(hex_len), 256)
        local val = random_hex(hex_len)
        return {
            voltic.result({
                id = "hex_1",
                name = val,
                description = hex_len .. " char hex string",
                score = 300,
                meta = { value = val },
            }),
        }
    end

    -- "hex" alone -> default 32 chars
    if query == "hex" then
        local val = random_hex(32)
        return {
            voltic.result({
                id = "hex_1",
                name = val,
                description = "32 char hex string",
                score = 300,
                meta = { value = val },
            }),
        }
    end

    -- "base64 <length>" or "b64 <length>" -> random base64 string
    local b64_len = query:match("^base64%s+(%d+)$") or query:match("^b64%s+(%d+)$")
    if b64_len then
        b64_len = math.min(tonumber(b64_len), 256)
        local val = random_base64(b64_len)
        return {
            voltic.result({
                id = "b64_1",
                name = val,
                description = b64_len .. " bytes as base64",
                score = 300,
                meta = { value = val },
            }),
        }
    end

    -- "base64" or "b64" alone -> default 32 bytes
    if query == "base64" or query == "b64" then
        local val = random_base64(32)
        return {
            voltic.result({
                id = "b64_1",
                name = val,
                description = "32 bytes as base64",
                score = 300,
                meta = { value = val },
            }),
        }
    end

    -- "alnum <length>" or "alpha <length>" -> random alphanumeric
    local alnum_len = query:match("^alnum%s+(%d+)$") or query:match("^alpha%s+(%d+)$")
    if alnum_len then
        alnum_len = math.min(tonumber(alnum_len), 256)
        local val = random_alphanumeric(alnum_len)
        return {
            voltic.result({
                id = "alnum_1",
                name = val,
                description = alnum_len .. " char alphanumeric string",
                score = 300,
                meta = { value = val },
            }),
        }
    end

    if query == "alnum" or query == "alpha" then
        local val = random_alphanumeric(24)
        return {
            voltic.result({
                id = "alnum_1",
                name = val,
                description = "24 char alphanumeric string",
                score = 300,
                meta = { value = val },
            }),
        }
    end

    -- Bare number -> N UUIDs
    local count = tonumber(query)
    if count then
        count = math.max(1, math.min(count, 10))
        local results = {}
        for i = 1, count do
            local id = uuid_v4()
            results[#results + 1] = voltic.result({
                id = "uuid_" .. i,
                name = id,
                description = "UUID v4 #" .. i,
                score = 300 - i,
                meta = { value = id },
            })
        end
        return results
    end

    -- Unknown subcommand
    return {
        voltic.result({
            id = "help",
            name = "Usage: uu | uu 5 | uu hex 16 | uu base64 32 | uu alnum 20",
            description = "Generate UUIDs or random strings",
            score = 100,
        }),
    }
end

function on_action(result, action)
    if not result.meta then return end
    local value = result.meta.value or result.name
    return "copy:" .. value
end

function on_actions(result)
    return {
        { key = "RET", label = "copy to clipboard" },
    }
end
