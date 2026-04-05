local voltic = require("voltic")

voltic.register({
    name = "epoch",
    prefix = "ep",
    description = "Unix timestamp converter",
})

local function trim(s)
    return s:match("^%s*(.-)%s*$") or s
end

local function get_now()
    local cached = voltic.cache.get("epoch:now")
    if cached then return tonumber(cached) end
    local raw = voltic.exec('powershell -NoProfile -Command "Write-Host ([int](Get-Date -UFormat %s))"')
    for line in raw:gmatch("[^\r\n]+") do
        local n = tonumber(trim(line))
        if n and n > 1000000000 then
            voltic.cache.set("epoch:now", tostring(n), 1)
            return n
        end
    end
    return 0
end

local function ts_to_date(ts)
    local raw = voltic.exec('powershell -NoProfile -Command "$d=[DateTimeOffset]::FromUnixTimeSeconds(' .. ts .. ');Write-Host $d.LocalDateTime.ToString(\'yyyy-MM-dd HH:mm:ss\');Write-Host $d.UtcDateTime.ToString(\'yyyy-MM-dd HH:mm:ss\')"')
    local lines = {}
    for line in raw:gmatch("[^\r\n]+") do
        local t = trim(line)
        if t:match("^%d%d%d%d%-%d%d%-%d%d") then
            lines[#lines + 1] = t
        end
    end
    return lines[1] or "?", lines[2] or "?"
end

local function date_to_ts(datestr)
    local raw = voltic.exec('powershell -NoProfile -Command "try{$d=[DateTime]::Parse(\'' .. datestr .. '\');Write-Host ([int]([DateTimeOffset]::new($d).ToUnixTimeSeconds()))}catch{Write-Host ERROR}"')
    for line in raw:gmatch("[^\r\n]+") do
        local t = trim(line)
        local n = tonumber(t)
        if n then return n end
    end
    return nil
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query

    if query == "" then
        local now = get_now()
        local local_dt, utc_dt = ts_to_date(now)
        return {
            voltic.result({
                id = "now_ts",
                name = "Now: " .. tostring(now),
                description = "Current Unix timestamp",
                score = 300,
                meta = { value = tostring(now) },
            }),
            voltic.result({
                id = "now_local",
                name = "Local: " .. local_dt,
                description = "Current local time",
                score = 290,
                meta = { value = local_dt },
            }),
            voltic.result({
                id = "now_utc",
                name = "UTC: " .. utc_dt,
                description = "Current UTC time",
                score = 280,
                meta = { value = utc_dt },
            }),
            voltic.result({
                id = "hint",
                name = "Type a timestamp or date to convert",
                description = "ep 1700000000 | ep 2024-01-15 14:30:00",
                score = 100,
            }),
        }
    end

    -- Try as Unix timestamp (number)
    local ts = tonumber(query)
    if ts then
        -- Handle millisecond timestamps
        if ts > 9999999999 then
            ts = math.floor(ts / 1000)
        end
        local local_dt, utc_dt = ts_to_date(ts)
        local now = get_now()
        local diff = ts - now
        local ago
        if diff > 0 then
            ago = "in " .. format_duration(diff)
        elseif diff < 0 then
            ago = format_duration(-diff) .. " ago"
        else
            ago = "now"
        end

        return {
            voltic.result({
                id = "ts_local",
                name = "Local: " .. local_dt,
                description = "Timestamp " .. tostring(ts) .. " (" .. ago .. ")",
                score = 300,
                meta = { value = local_dt },
            }),
            voltic.result({
                id = "ts_utc",
                name = "UTC: " .. utc_dt,
                description = "Timestamp " .. tostring(ts),
                score = 290,
                meta = { value = utc_dt },
            }),
            voltic.result({
                id = "ts_copy",
                name = "Timestamp: " .. tostring(ts),
                description = ago,
                score = 280,
                meta = { value = tostring(ts) },
            }),
        }
    end

    -- Try as date string
    local result_ts = date_to_ts(query)
    if result_ts then
        return {
            voltic.result({
                id = "date_ts",
                name = "Timestamp: " .. tostring(result_ts),
                description = query .. " -> Unix timestamp",
                score = 300,
                meta = { value = tostring(result_ts) },
            }),
            voltic.result({
                id = "date_ms",
                name = "Milliseconds: " .. tostring(result_ts * 1000),
                description = query .. " -> Unix timestamp (ms)",
                score = 290,
                meta = { value = tostring(result_ts * 1000) },
            }),
        }
    end

    return {
        voltic.result({
            id = "invalid",
            name = "Not recognized",
            description = "Try: ep 1700000000 | ep 2024-01-15 14:30:00",
            score = 100,
        }),
    }
end

function format_duration(seconds)
    local d = math.floor(seconds / 86400)
    local h = math.floor((seconds % 86400) / 3600)
    local m = math.floor((seconds % 3600) / 60)
    if d > 0 then
        return string.format("%dd %dh %dm", d, h, m)
    elseif h > 0 then
        return string.format("%dh %dm", h, m)
    else
        return string.format("%dm", m)
    end
end

function on_action(result, action)
    if result.meta and result.meta.value then
        return "copy:" .. result.meta.value
    end
end

function on_actions(result)
    return {
        { key = "RET", label = "copy to clipboard" },
    }
end
