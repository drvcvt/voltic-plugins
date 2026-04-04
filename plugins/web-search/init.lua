local voltic = require("voltic")

voltic.register({
    name = "web-search",
    prefix = "ws",
    description = "Search the web",
})

local engines = {
    { key = "g",   name = "Google",     url = "https://www.google.com/search?q=%s" },
    { key = "ddg", name = "DuckDuckGo", url = "https://duckduckgo.com/?q=%s" },
    { key = "yt",  name = "YouTube",    url = "https://www.youtube.com/results?search_query=%s" },
    { key = "gh",  name = "GitHub",     url = "https://github.com/search?q=%s&type=repositories" },
    { key = "r",   name = "Reddit",     url = "https://www.reddit.com/search/?q=%s" },
    { key = "w",   name = "Wikipedia",  url = "https://en.wikipedia.org/w/index.php?search=%s" },
    { key = "npm", name = "npm",        url = "https://www.npmjs.com/search?q=%s" },
    { key = "cr",  name = "crates.io",  url = "https://crates.io/search?q=%s" },
    { key = "so",  name = "Stack Overflow", url = "https://stackoverflow.com/search?q=%s" },
    { key = "maps", name = "Google Maps", url = "https://www.google.com/maps/search/%s" },
}

local function url_encode(str)
    return str:gsub("([^%w%-_.~])", function(c)
        return string.format("%%%02X", c:byte())
    end)
end

local function build_url(template, query)
    return template:gsub("%%s", url_encode(query))
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query

    -- Empty: show available engines
    if query == "" then
        local results = {}
        for i, eng in ipairs(engines) do
            results[#results + 1] = voltic.result({
                id = "engine:" .. eng.key,
                name = eng.key .. " — " .. eng.name,
                description = "ws " .. eng.key .. " <query>",
                score = 300 - i,
                meta = { engine = eng.key },
            })
        end
        return results
    end

    -- Check if query starts with an engine key
    local parts = query:match("^(%S+)%s+(.+)$")
    if parts then
        local key, rest = query:match("^(%S+)%s+(.+)$")
        for _, eng in ipairs(engines) do
            if eng.key == key then
                local url = build_url(eng.url, rest)
                return {
                    voltic.result({
                        id = "search:" .. eng.key,
                        name = eng.name .. ": " .. rest,
                        description = url,
                        score = 300,
                        meta = { url = url, query = rest, engine = eng.key },
                    }),
                }
            end
        end
    end

    -- Default: show all engines with this query
    local results = {}
    for i, eng in ipairs(engines) do
        local url = build_url(eng.url, query)
        results[#results + 1] = voltic.result({
            id = "search:" .. eng.key,
            name = eng.name .. ": " .. query,
            description = url,
            score = 300 - i,
            meta = { url = url, query = query, engine = eng.key },
        })
    end
    return results
end

function on_action(result, action)
    if result.meta and result.meta.url then
        return "open:" .. result.meta.url
    end
end

function on_actions(result)
    return {
        { key = "RET", label = "open in browser" },
    }
end
