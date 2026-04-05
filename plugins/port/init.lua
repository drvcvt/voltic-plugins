local voltic = require("voltic")

voltic.register({
    name = "port",
    prefix = "pt",
    description = "Port listener",
})

local function trim(s)
    return s:match("^%s*(.-)%s*$") or s
end

local CACHE_TTL = 5

local function get_listeners()
    local cached = voltic.cache.get("port:listeners")
    if cached then
        local ok, data = pcall(voltic.json.decode, cached)
        if ok then return data end
    end

    local raw = voltic.exec('powershell -NoProfile -Command "Get-NetTCPConnection -State Listen -ErrorAction SilentlyContinue | Sort-Object LocalPort | ForEach-Object { $p=try{(Get-Process -Id $_.OwningProcess -ErrorAction SilentlyContinue).ProcessName}catch{\'?\'}; Write-Host (\'{0}|{1}|{2}\' -f $_.LocalPort,$_.OwningProcess,$p) }"')

    local listeners = {}
    local seen = {}
    for line in raw:gmatch("[^\r\n]+") do
        local t = trim(line)
        local port, pid, name = t:match("^(%d+)|(%d+)|(.+)$")
        if port and not seen[port] then
            seen[port] = true
            listeners[#listeners + 1] = {
                port = tonumber(port),
                pid = tonumber(pid),
                name = trim(name),
            }
        end
    end

    voltic.cache.set("port:listeners", voltic.json.encode(listeners), CACHE_TTL)
    return listeners
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query

    local listeners = get_listeners()
    local results = {}

    if #listeners == 0 then
        return {
            voltic.result({
                id = "loading",
                name = "Loading listening ports...",
                description = "Scanning TCP connections",
                score = 100,
            }),
        }
    end

    -- Filter
    local filtered = {}
    if query == "" then
        filtered = listeners
    else
        local port_q = tonumber(query)
        local name_q = query:lower()
        for _, l in ipairs(listeners) do
            if port_q and l.port == port_q then
                filtered[#filtered + 1] = l
            elseif l.name:lower():find(name_q, 1, true) then
                filtered[#filtered + 1] = l
            elseif tostring(l.port):find(query, 1, true) then
                filtered[#filtered + 1] = l
            end
        end
    end

    if #filtered == 0 then
        return {
            voltic.result({
                id = "none",
                name = "No listeners matching '" .. query .. "'",
                description = tostring(#listeners) .. " total listening ports",
                score = 100,
            }),
        }
    end

    -- Limit to 20
    for i = 1, math.min(#filtered, 20) do
        local l = filtered[i]
        results[#results + 1] = voltic.result({
            id = "port:" .. l.port,
            name = ":" .. l.port .. "  " .. l.name,
            description = "PID " .. l.pid,
            score = 300 - i,
            meta = { port = l.port, pid = l.pid, name = l.name },
        })
    end

    return results
end

function on_action(result, action)
    if not result.meta then return end

    if action == "default" or action == "kill" then
        local pid = result.meta.pid
        local name = result.meta.name or "?"
        local port = result.meta.port or "?"
        voltic.exec('taskkill /PID ' .. pid .. ' /F')
        voltic.log.info("killed " .. name .. " on port " .. port .. " (PID " .. pid .. ")")
        return
    end

    if action == "copy" then
        return "copy:" .. tostring(result.meta.port)
    end
end

function on_actions(result)
    if result.meta and result.meta.pid then
        return {
            { key = "RET", label = "kill process" },
            { key = "C-RET", label = "copy port" },
        }
    end
    return {{ key = "RET", label = "select" }}
end
