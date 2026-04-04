local voltic = require("voltic")

voltic.register({
    name = "ip",
    prefix = "ip",
    description = "Network & IP info",
})

local CACHE_TTL = 60 -- 1 minute

local function trim(s)
    return s:match("^%s*(.-)%s*$") or s
end

local function get_public_ip()
    local cached = voltic.cache.get("ip:public")
    if cached then return cached end

    local ok, resp = pcall(voltic.http.get, "https://api.ipify.org")
    if not ok or not resp.ok then return nil end

    local ip = trim(resp.body)
    voltic.cache.set("ip:public", ip, CACHE_TTL)
    return ip
end

local function get_ip_info(ip)
    local cache_key = "ip:info:" .. ip
    local cached = voltic.cache.get(cache_key)
    if cached then
        local ok, data = pcall(voltic.json.decode, cached)
        if ok then return data end
    end

    local ok, resp = pcall(voltic.http.get, "https://ipinfo.io/" .. ip .. "/json")
    if not ok or not resp.ok then return nil end

    voltic.cache.set(cache_key, resp.body, CACHE_TTL * 5)
    local ok2, data = pcall(voltic.json.decode, resp.body)
    if ok2 then return data end
    return nil
end

local function get_local_ip()
    local cached = voltic.cache.get("ip:local")
    if cached then return cached end

    local raw = voltic.exec('powershell -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch \'Loopback\' -and $_.IPAddress -ne \'127.0.0.1\' } | Select-Object -First 1).IPAddress"')
    local ip = trim(raw)
    if ip and #ip > 0 then
        voltic.cache.set("ip:local", ip, CACHE_TTL)
        return ip
    end
    return nil
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query

    local results = {}

    -- Local IP
    local local_ip = get_local_ip()
    if local_ip then
        results[#results + 1] = voltic.result({
            id = "local",
            name = "Local: " .. local_ip,
            description = "LAN IP address",
            score = 300,
            meta = { value = local_ip },
        })
    end

    -- Public IP
    local public_ip = get_public_ip()
    if public_ip then
        results[#results + 1] = voltic.result({
            id = "public",
            name = "Public: " .. public_ip,
            description = "External IP address",
            score = 290,
            meta = { value = public_ip },
        })

        -- Geo info from ipinfo.io
        local info = get_ip_info(public_ip)
        if info then
            if info.city and info.region then
                local loc = info.city .. ", " .. info.region
                if info.country then loc = loc .. " (" .. info.country .. ")" end
                results[#results + 1] = voltic.result({
                    id = "geo",
                    name = "Location: " .. loc,
                    description = "Approximate geolocation",
                    score = 280,
                    meta = { value = loc },
                })
            end
            if info.org then
                results[#results + 1] = voltic.result({
                    id = "org",
                    name = "ISP: " .. info.org,
                    description = "Organization / ISP",
                    score = 270,
                    meta = { value = info.org },
                })
            end
            if info.timezone then
                results[#results + 1] = voltic.result({
                    id = "tz",
                    name = "Timezone: " .. info.timezone,
                    description = "Timezone from IP",
                    score = 260,
                    meta = { value = info.timezone },
                })
            end
        end
    end

    -- If query is a specific IP, look it up
    if query:match("^%d+%.%d+%.%d+%.%d+$") then
        local info = get_ip_info(query)
        if info then
            results = {}
            results[#results + 1] = voltic.result({
                id = "lookup_ip",
                name = "IP: " .. query,
                description = "Lookup result",
                score = 300,
                meta = { value = query },
            })
            if info.city and info.region then
                local loc = info.city .. ", " .. info.region
                if info.country then loc = loc .. " (" .. info.country .. ")" end
                results[#results + 1] = voltic.result({
                    id = "lookup_geo",
                    name = "Location: " .. loc,
                    description = "Geolocation for " .. query,
                    score = 290,
                    meta = { value = loc },
                })
            end
            if info.org then
                results[#results + 1] = voltic.result({
                    id = "lookup_org",
                    name = "ISP: " .. info.org,
                    description = "Organization",
                    score = 280,
                    meta = { value = info.org },
                })
            end
            if info.hostname then
                results[#results + 1] = voltic.result({
                    id = "lookup_host",
                    name = "Hostname: " .. info.hostname,
                    description = "Reverse DNS",
                    score = 270,
                    meta = { value = info.hostname },
                })
            end
        end
    end

    if #results == 0 then
        results[#results + 1] = voltic.result({
            id = "loading",
            name = "Fetching network info...",
            description = "Getting local and public IP addresses",
            score = 100,
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
    return {
        { key = "RET", label = "copy to clipboard" },
    }
end
