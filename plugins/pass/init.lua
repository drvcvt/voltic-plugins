local voltic = require("voltic")

voltic.register({
    name = "pass",
    prefix = "pw",
    description = "Password generator",
})

-- Seed RNG from table addresses
local function seed_rng()
    local t1, t2 = {}, {}
    local a1 = tonumber(tostring(t1):match("0x(%x+)"), 16) or 12345
    local a2 = tonumber(tostring(t2):match("0x(%x+)"), 16) or 67890
    math.randomseed(a1 + a2)
    for _ = 1, 10 do math.random() end
end

seed_rng()

local LOWER = "abcdefghijklmnopqrstuvwxyz"
local UPPER = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local DIGITS = "0123456789"
local SYMBOLS = "!@#$%^&*()-_=+[]{}|;:,.<>?"
local ALL = LOWER .. UPPER .. DIGITS .. SYMBOLS
local ALNUM = LOWER .. UPPER .. DIGITS

local function random_from(charset, length)
    local result = {}
    for i = 1, length do
        local idx = math.random(1, #charset)
        result[i] = charset:sub(idx, idx)
    end
    return table.concat(result)
end

-- Shuffle a string
local function shuffle(s)
    local chars = {}
    for i = 1, #s do chars[i] = s:sub(i, i) end
    for i = #chars, 2, -1 do
        local j = math.random(1, i)
        chars[i], chars[j] = chars[j], chars[i]
    end
    return table.concat(chars)
end

-- Generate a password with guaranteed character classes
local function gen_password(length, use_symbols)
    if length < 4 then length = 4 end
    local charset = use_symbols and ALL or ALNUM

    -- Guarantee at least one from each class
    local required = random_from(LOWER, 1)
        .. random_from(UPPER, 1)
        .. random_from(DIGITS, 1)
    if use_symbols then
        required = required .. random_from(SYMBOLS, 1)
    end

    local remaining = length - #required
    local rest = random_from(charset, remaining)
    return shuffle(required .. rest)
end

-- Common words for passphrases
local WORDS = {
    "alpha","brave","cedar","delta","eagle","flame","globe","house","ivory","joker",
    "karma","lemon","maple","noble","ocean","piano","quilt","river","solar","tiger",
    "ultra","vivid","water","xenon","yacht","zebra","amber","blaze","coral","drift",
    "ember","frost","grain","haven","index","jewel","knack","lunar","metro","nexus",
    "orbit","pixel","query","radar","spine","torch","unity","vault","wheat","axiom",
    "birch","clash","dwell","epoch","forge","gleam","haste","inlet","jaunt","kneel",
    "lodge","marsh","nerve","onset","plumb","realm","sweep","thorn","usher","verge",
}

local function gen_passphrase(word_count, separator)
    local parts = {}
    for i = 1, word_count do
        local idx = math.random(1, #WORDS)
        parts[i] = WORDS[idx]
    end
    return table.concat(parts, separator)
end

-- Entropy calculation (rough)
local function calc_entropy(length, charset_size)
    return math.floor(length * math.log(charset_size) / math.log(2))
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query
    seed_rng()

    -- Parse options
    local length = 16
    local use_symbols = true
    local mode = "mixed" -- mixed, alpha, pin, phrase

    if query == "" then
        -- Default: show a variety
    elseif query:match("^%d+$") then
        length = math.min(tonumber(query), 128)
    elseif query == "pin" or query:match("^pin%s+%d+$") then
        mode = "pin"
        length = tonumber(query:match("%d+")) or 6
    elseif query == "phrase" or query:match("^phrase%s+%d+$") then
        mode = "phrase"
        length = tonumber(query:match("%d+")) or 4
    elseif query == "alpha" or query == "alnum" then
        use_symbols = false
    elseif query == "strong" then
        length = 32
    elseif query == "mega" then
        length = 64
    end

    local results = {}

    if mode == "pin" then
        for i = 1, 3 do
            local pin = random_from(DIGITS, length)
            local entropy = calc_entropy(length, 10)
            results[#results + 1] = voltic.result({
                id = "pin_" .. i,
                name = pin,
                description = length .. "-digit PIN (" .. entropy .. " bits)",
                score = 300 - i,
                meta = { value = pin },
            })
        end
        return results
    end

    if mode == "phrase" then
        local separators = {"-", ".", " ", "_"}
        for i, sep in ipairs(separators) do
            local phrase = gen_passphrase(length, sep)
            local entropy = calc_entropy(length, #WORDS)
            results[#results + 1] = voltic.result({
                id = "phrase_" .. i,
                name = phrase,
                description = length .. " words, '" .. sep .. "' separator (" .. entropy .. " bits)",
                score = 300 - i,
                meta = { value = phrase },
            })
        end
        return results
    end

    -- Mixed mode: generate several options
    -- 1. Strong with symbols
    local p1 = gen_password(length, true)
    local e1 = calc_entropy(length, #ALL)
    results[#results + 1] = voltic.result({
        id = "strong",
        name = p1,
        description = length .. " chars, all classes (" .. e1 .. " bits)",
        score = 300,
        meta = { value = p1 },
    })

    -- 2. Alphanumeric only
    local p2 = gen_password(length, false)
    local e2 = calc_entropy(length, #ALNUM)
    results[#results + 1] = voltic.result({
        id = "alnum",
        name = p2,
        description = length .. " chars, no symbols (" .. e2 .. " bits)",
        score = 290,
        meta = { value = p2 },
    })

    -- 3. Passphrase
    local phrase = gen_passphrase(4, "-")
    local ep = calc_entropy(4, #WORDS)
    results[#results + 1] = voltic.result({
        id = "phrase",
        name = phrase,
        description = "4-word passphrase (" .. ep .. " bits)",
        score = 280,
        meta = { value = phrase },
    })

    -- 4. PIN
    local pin = random_from(DIGITS, 6)
    results[#results + 1] = voltic.result({
        id = "pin",
        name = pin,
        description = "6-digit PIN",
        score = 270,
        meta = { value = pin },
    })

    -- Help
    results[#results + 1] = voltic.result({
        id = "help",
        name = "Options: pw 32 | pw pin | pw phrase 5 | pw alpha | pw strong",
        description = "Customize password generation",
        score = 100,
    })

    return results
end

function on_action(result, action)
    if result.meta and result.meta.value then
        return "copy:" .. result.meta.value
    end
end

function on_actions(result)
    if result.meta and result.meta.value then
        return {{ key = "RET", label = "copy to clipboard" }}
    end
    return {{ key = "RET", label = "select" }}
end
