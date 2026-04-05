local voltic = require("voltic")

voltic.register({
    name = "regex",
    prefix = "re",
    description = "Regex tester (Lua patterns)",
})

-- Split "pattern /// text" or "pattern | text" or just pattern
local function parse_query(q)
    -- Separator: " /// " or " | " or " :: "
    local sep_positions = {
        q:find("%s///%s"),
        q:find("%s|%s"),
        q:find("%s::%s"),
    }
    for _, pos in ipairs(sep_positions) do
        if pos then
            local sep_len = (q:sub(pos, pos + 4) == " /// ") and 5 or 3
            local pattern = q:sub(1, pos - 1):match("^%s*(.-)%s*$")
            local text = q:sub(pos + sep_len):match("^%s*(.-)%s*$")
            return pattern, text
        end
    end
    return q, nil
end

local function escape_display(s, max_len)
    max_len = max_len or 80
    s = s:gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")
    if #s > max_len then
        s = s:sub(1, max_len - 3) .. "..."
    end
    return s
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query

    if query == "" then
        return {
            voltic.result({
                id = "hint",
                name = "Test a Lua pattern against text",
                description = "re %d+ /// hello 42 world 99 | re (%w+)@(%w+) /// foo@bar",
                score = 100,
            }),
            voltic.result({
                id = "syntax",
                name = "Lua pattern syntax",
                description = "%d digit  %w alphanum  %s space  %a alpha  + * - ? . ^ $",
                score = 90,
            }),
        }
    end

    local pattern, text = parse_query(query)
    if not pattern or pattern == "" then
        return {
            voltic.result({
                id = "empty",
                name = "Empty pattern",
                description = "Provide a pattern to test",
                score = 100,
            }),
        }
    end

    local results = {}

    -- Validate pattern
    local valid_ok, _ = pcall(function() return string.find("", pattern) end)
    if not valid_ok then
        return {
            voltic.result({
                id = "invalid",
                name = "Invalid pattern: " .. pattern,
                description = "Check your Lua pattern syntax",
                score = 300,
            }),
        }
    end

    if not text or text == "" then
        -- No text to match against: show pattern info
        results[#results + 1] = voltic.result({
            id = "no_text",
            name = "Pattern: " .. pattern,
            description = "Add text after /// | or :: to test",
            score = 300,
            meta = { value = pattern },
        })
        return results
    end

    -- Find all matches
    local matches = {}
    local match_count = 0
    for start_pos, end_pos, captures in (function()
        local pos = 1
        return function()
            if pos > #text then return nil end
            local s, e = text:find(pattern, pos)
            if not s then return nil end
            -- Captures
            local caps = {text:match(pattern, pos)}
            pos = e + 1
            if e < s then pos = s + 1 end -- avoid infinite loop on empty match
            return s, e, caps
        end
    end)() do
        match_count = match_count + 1
        matches[#matches + 1] = {
            start = start_pos,
            end_pos = end_pos,
            full = text:sub(start_pos, end_pos),
            captures = captures,
        }
        if match_count >= 20 then break end
    end

    if match_count == 0 then
        results[#results + 1] = voltic.result({
            id = "no_match",
            name = "No match",
            description = "Pattern: " .. escape_display(pattern) .. " | Text: " .. escape_display(text),
            score = 300,
        })
        return results
    end

    -- Summary
    results[#results + 1] = voltic.result({
        id = "summary",
        name = match_count .. " match" .. (match_count == 1 and "" or "es"),
        description = "Pattern: " .. escape_display(pattern) .. " | Text: " .. escape_display(text),
        score = 350,
    })

    -- Individual matches
    for i, m in ipairs(matches) do
        local cap_str = ""
        if m.captures and #m.captures > 0 then
            local cap_parts = {}
            for j, c in ipairs(m.captures) do
                cap_parts[#cap_parts + 1] = string.format("$%d=%s", j, escape_display(tostring(c), 30))
            end
            cap_str = " [" .. table.concat(cap_parts, ", ") .. "]"
        end
        results[#results + 1] = voltic.result({
            id = "match_" .. i,
            name = escape_display(m.full, 100),
            description = string.format("pos %d-%d%s", m.start, m.end_pos, cap_str),
            score = 300 - i,
            meta = { value = m.full },
        })
    end

    -- Substitution preview
    local sub_ok, subbed = pcall(string.gsub, text, pattern, "")
    if sub_ok and subbed ~= text then
        results[#results + 1] = voltic.result({
            id = "removed",
            name = "With matches removed: " .. escape_display(subbed, 80),
            description = "gsub(text, pattern, '')",
            score = 100,
            meta = { value = subbed },
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
        return {{ key = "RET", label = "copy match" }}
    end
    return {{ key = "RET", label = "select" }}
end
