local voltic = require("voltic")

voltic.register({
    name = "define",
    prefix = "df",
    description = "Dictionary — word definitions",
})

local CACHE_TTL = 3600 -- 1 hour

local function lookup(word)
    -- Check cache first
    local cache_key = "def:" .. word:lower()
    local cached = voltic.cache.get(cache_key)
    if cached then
        local ok, data = pcall(voltic.json.decode, cached)
        if ok then return data end
    end

    -- Fetch from API
    local url = "https://api.dictionaryapi.dev/api/v2/entries/en/" .. word
    local ok, resp = pcall(voltic.http.get, url)
    if not ok then
        voltic.log.error("HTTP request failed: " .. tostring(resp))
        return nil, "network error"
    end

    if not resp.ok then
        if resp.status == 404 then
            return nil, "word not found"
        end
        return nil, "API error (HTTP " .. tostring(resp.status) .. ")"
    end

    local ok2, data = pcall(voltic.json.decode, resp.body)
    if not ok2 or not data then
        return nil, "failed to parse response"
    end

    -- Cache the raw response
    voltic.cache.set(cache_key, resp.body, CACHE_TTL)
    return data
end

local function truncate(str, max_len)
    if #str <= max_len then return str end
    return str:sub(1, max_len - 3) .. "..."
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query -- trim

    if query == "" then
        return {
            voltic.result({
                id = "hint",
                name = "Type a word to define",
                description = "df hello, df ubiquitous, df ephemeral",
                score = 100,
            }),
        }
    end

    -- Only look up single words or hyphenated words to avoid junk queries
    if not query:match("^[%a%-]+$") then
        return {
            voltic.result({
                id = "invalid",
                name = "Enter a single English word",
                description = "e.g. df serendipity",
                score = 100,
            }),
        }
    end

    local data, err = lookup(query)

    if not data then
        return {
            voltic.result({
                id = "error",
                name = err or "Lookup failed",
                description = "Could not find definition for '" .. query .. "'",
                score = 100,
            }),
        }
    end

    local results = {}

    -- data is an array of entries (usually 1)
    for _, entry in ipairs(data) do
        local word = entry.word or query
        local phonetic = entry.phonetic or ""

        -- Show phonetic as first result if available
        if phonetic ~= "" then
            results[#results + 1] = voltic.result({
                id = "phonetic_" .. word,
                name = word .. "  " .. phonetic,
                description = "Pronunciation",
                score = 300,
                meta = { value = word .. " " .. phonetic },
            })
        end

        -- Iterate meanings
        local meanings = entry.meanings or {}
        for mi, meaning in ipairs(meanings) do
            local part_of_speech = meaning.partOfSpeech or ""

            local definitions = meaning.definitions or {}
            for di, def in ipairs(definitions) do
                local text = def.definition or ""
                if text ~= "" then
                    local desc = part_of_speech
                    local example = def.example
                    if example and example ~= "" then
                        desc = desc .. ' -- "' .. truncate(example, 60) .. '"'
                    end

                    results[#results + 1] = voltic.result({
                        id = "def_" .. mi .. "_" .. di,
                        name = truncate(text, 120),
                        description = desc,
                        score = 250 - mi * 10 - di,
                        meta = { value = text, word = word, pos = part_of_speech },
                    })
                end

                -- Limit to 3 definitions per part of speech
                if di >= 3 then break end
            end

            -- Show synonyms if present
            local synonyms = meaning.synonyms or {}
            if #synonyms > 0 then
                local syn_text = table.concat(synonyms, ", ", 1, math.min(#synonyms, 8))
                results[#results + 1] = voltic.result({
                    id = "syn_" .. mi,
                    name = "Synonyms: " .. syn_text,
                    description = part_of_speech,
                    score = 200 - mi * 10,
                    meta = { value = syn_text },
                })
            end
        end
    end

    if #results == 0 then
        results[#results + 1] = voltic.result({
            id = "empty",
            name = "No definitions found",
            description = "Try a different word",
            score = 100,
        })
    end

    return results
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
