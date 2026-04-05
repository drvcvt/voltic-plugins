local voltic = require("voltic")

voltic.register({
    name = "json",
    prefix = "jf",
    description = "JSON formatter",
})

-- Simple JSON pretty printer (indentation only, no re-ordering)
local function pretty_print(str, indent)
    indent = indent or "  "
    local level = 0
    local in_string = false
    local escaped = false
    local result = {}
    local newline_pending = false

    for i = 1, #str do
        local ch = str:sub(i, i)

        if escaped then
            result[#result + 1] = ch
            escaped = false
        elseif ch == "\\" and in_string then
            result[#result + 1] = ch
            escaped = true
        elseif ch == '"' then
            if newline_pending then
                result[#result + 1] = "\n" .. string.rep(indent, level)
                newline_pending = false
            end
            result[#result + 1] = ch
            in_string = not in_string
        elseif in_string then
            result[#result + 1] = ch
        elseif ch == "{" or ch == "[" then
            if newline_pending then
                result[#result + 1] = "\n" .. string.rep(indent, level)
                newline_pending = false
            end
            result[#result + 1] = ch
            level = level + 1
            newline_pending = true
        elseif ch == "}" or ch == "]" then
            level = level - 1
            result[#result + 1] = "\n" .. string.rep(indent, level) .. ch
            newline_pending = false
        elseif ch == "," then
            result[#result + 1] = ","
            newline_pending = true
        elseif ch == ":" then
            result[#result + 1] = ": "
        elseif ch ~= " " and ch ~= "\n" and ch ~= "\r" and ch ~= "\t" then
            if newline_pending then
                result[#result + 1] = "\n" .. string.rep(indent, level)
                newline_pending = false
            end
            result[#result + 1] = ch
        elseif newline_pending then
            -- skip whitespace after comma/brace
        else
            -- skip whitespace in general
        end
    end

    return table.concat(result)
end

-- Minify: strip all non-essential whitespace
local function minify(str)
    local in_string = false
    local escaped = false
    local result = {}

    for i = 1, #str do
        local ch = str:sub(i, i)

        if escaped then
            result[#result + 1] = ch
            escaped = false
        elseif ch == "\\" and in_string then
            result[#result + 1] = ch
            escaped = true
        elseif ch == '"' then
            result[#result + 1] = ch
            in_string = not in_string
        elseif in_string then
            result[#result + 1] = ch
        elseif ch ~= " " and ch ~= "\n" and ch ~= "\r" and ch ~= "\t" then
            result[#result + 1] = ch
        end
    end

    return table.concat(result)
end

-- Validate: try decode + re-encode
local function validate(str)
    local ok, data = pcall(voltic.json.decode, str)
    if not ok then
        return false, tostring(data)
    end
    return true, nil
end

-- Count keys/values
local function json_stats(str)
    local ok, data = pcall(voltic.json.decode, str)
    if not ok then return nil end

    local function count(obj)
        local keys = 0
        local values = 0
        local arrays = 0
        local objects = 0
        if type(obj) == "table" then
            -- Check if array
            local is_array = #obj > 0
            if is_array then
                arrays = arrays + 1
                values = values + #obj
                for _, v in ipairs(obj) do
                    local k2, v2, a2, o2 = count(v)
                    keys = keys + k2
                    values = values + v2
                    arrays = arrays + a2
                    objects = objects + o2
                end
            else
                objects = objects + 1
                for k, v in pairs(obj) do
                    keys = keys + 1
                    local k2, v2, a2, o2 = count(v)
                    keys = keys + k2
                    values = values + v2
                    arrays = arrays + a2
                    objects = objects + o2
                end
            end
        end
        return keys, values, arrays, objects
    end

    return count(data)
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query

    if query == "" then
        return {
            voltic.result({
                id = "hint",
                name = "Paste JSON to format",
                description = 'jf {"key":"value"} — prettify, minify, validate',
                score = 100,
            }),
        }
    end

    local results = {}
    local valid, err = validate(query)

    if valid then
        local pretty = pretty_print(query)
        local mini = minify(query)
        local lines = 1
        for _ in pretty:gmatch("\n") do lines = lines + 1 end

        results[#results + 1] = voltic.result({
            id = "pretty",
            name = "Prettified (" .. lines .. " lines)",
            description = pretty:sub(1, 120),
            score = 300,
            meta = { value = pretty },
        })

        results[#results + 1] = voltic.result({
            id = "mini",
            name = "Minified (" .. #mini .. " chars)",
            description = mini:sub(1, 120),
            score = 290,
            meta = { value = mini },
        })

        results[#results + 1] = voltic.result({
            id = "valid",
            name = "Valid JSON",
            description = #query .. " chars input",
            score = 280,
        })

        local keys, values, arrays, objects = json_stats(query)
        if keys then
            results[#results + 1] = voltic.result({
                id = "stats",
                name = string.format("%d keys, %d values, %d objects, %d arrays", keys, values, objects, arrays),
                description = "JSON structure stats",
                score = 270,
                meta = { value = string.format("keys=%d values=%d objects=%d arrays=%d", keys, values, objects, arrays) },
            })
        end
    else
        results[#results + 1] = voltic.result({
            id = "invalid",
            name = "Invalid JSON",
            description = err or "Parse error",
            score = 300,
        })

        -- Try to fix common issues and re-parse
        local fixed = query
        -- Single quotes -> double quotes (crude but helpful)
        if query:find("'") and not query:find('"') then
            fixed = query:gsub("'", '"')
            if validate(fixed) then
                local pretty = pretty_print(fixed)
                results[#results + 1] = voltic.result({
                    id = "fixed",
                    name = "Fixed (single -> double quotes)",
                    description = pretty:sub(1, 120),
                    score = 290,
                    meta = { value = pretty },
                })
            end
        end
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
        return {{ key = "RET", label = "copy to clipboard" }}
    end
    return {{ key = "RET", label = "select" }}
end
