local voltic = require("voltic")

voltic.register({
    name = "sysinfo",
    prefix = "sys",
    description = "System information",
})

local function trim(s)
    return s:match("^%s*(.-)%s*$") or s
end

local function exec_lines(cmd)
    local raw = voltic.exec(cmd)
    local lines = {}
    for line in raw:gmatch("[^\r\n]+") do
        local trimmed = trim(line)
        if #trimmed > 0 then
            lines[#lines + 1] = trimmed
        end
    end
    return lines
end

local function get_ram_info()
    local lines = exec_lines('wmic OS get FreePhysicalMemory,TotalVisibleMemorySize /value')
    local free, total
    for _, line in ipairs(lines) do
        local k, v = line:match("^(.-)=(.+)$")
        if k and v then
            k = trim(k)
            v = trim(v)
            if k == "FreePhysicalMemory" then free = tonumber(v) end
            if k == "TotalVisibleMemorySize" then total = tonumber(v) end
        end
    end
    if free and total then
        local used = total - free
        local pct = math.floor(used / total * 100)
        return string.format("%d%% used (%.1f / %.1f GB)",
            pct, used / 1048576, total / 1048576)
    end
    return "unknown"
end

local function get_disk_info()
    local lines = exec_lines('wmic logicaldisk where "DriveType=3" get DeviceID,FreeSpace,Size /value')
    local results = {}
    local current = {}
    for _, line in ipairs(lines) do
        local k, v = line:match("^(.-)=(.+)$")
        if k and v then
            k = trim(k)
            v = trim(v)
            current[k] = v
            if k == "Size" then
                local drive = current["DeviceID"] or "?"
                local total = tonumber(current["Size"]) or 0
                local free = tonumber(current["FreeSpace"]) or 0
                local used = total - free
                local pct = total > 0 and math.floor(used / total * 100) or 0
                results[#results + 1] = string.format("%s %d%% used (%.0f GB free)",
                    drive, pct, free / 1073741824)
                current = {}
            end
        end
    end
    return results
end

local function get_ip()
    local lines = exec_lines('powershell -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.InterfaceAlias -notmatch \"Loopback\" -and $_.IPAddress -ne \"127.0.0.1\" } | Select-Object -First 1).IPAddress"')
    return lines[1] or "unknown"
end

local function get_uptime()
    local lines = exec_lines('powershell -Command "$os = Get-CimInstance Win32_OperatingSystem; $up = (Get-Date) - $os.LastBootUpTime; \'{0}d {1}h {2}m\' -f $up.Days, $up.Hours, $up.Minutes"')
    return lines[1] or "unknown"
end

local function get_cpu()
    local lines = exec_lines('wmic cpu get Name /value')
    for _, line in ipairs(lines) do
        local k, v = line:match("^(.-)=(.+)$")
        if k and trim(k) == "Name" then
            return trim(v)
        end
    end
    return "unknown"
end

local function get_top_processes()
    local lines = exec_lines('powershell -Command "Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 5 | ForEach-Object { \'{0}: {1:N0} MB\' -f $_.ProcessName, ($_.WorkingSet64 / 1MB) }"')
    return lines
end

-- Cached results per category
local info_cache = {}
local cache_ts = 0
local CACHE_TTL = 10 -- seconds

local function get_all_info()
    local now = os.clock and os.clock() or 0
    -- os is sandboxed, use a simple counter instead
    -- We'll just always refresh for now since cache.get handles TTL
    local cached = voltic.cache.get("sysinfo_all")
    if cached then
        return voltic.json.decode(cached)
    end

    local info = {}

    -- RAM
    local ram = get_ram_info()
    info[#info + 1] = { id = "ram", name = "RAM: " .. ram, desc = "Memory usage" }

    -- CPU
    local cpu = get_cpu()
    info[#info + 1] = { id = "cpu", name = "CPU: " .. cpu, desc = "Processor" }

    -- Disks
    local disks = get_disk_info()
    for i, disk in ipairs(disks) do
        info[#info + 1] = { id = "disk" .. i, name = "Disk: " .. disk, desc = "Storage" }
    end

    -- IP
    local ip = get_ip()
    info[#info + 1] = { id = "ip", name = "IP: " .. ip, desc = "Local IP address", meta_val = ip }

    -- Uptime
    local uptime = get_uptime()
    info[#info + 1] = { id = "uptime", name = "Uptime: " .. uptime, desc = "System uptime" }

    -- Top processes
    local procs = get_top_processes()
    for i, proc in ipairs(procs) do
        info[#info + 1] = { id = "proc" .. i, name = proc, desc = "Top process #" .. i }
    end

    voltic.cache.set("sysinfo_all", voltic.json.encode(info), 10)
    return info
end

function on_search(query)
    if query == "" then
        -- Show all system info
        local info = get_all_info()
        local results = {}
        for i, item in ipairs(info) do
            results[#results + 1] = voltic.result({
                id = item.id,
                name = item.name,
                description = item.desc,
                score = 300 - i,
                meta = { value = item.meta_val or item.name },
            })
        end
        return results
    end

    -- Filter by query
    local info = get_all_info()
    local results = {}
    local q = query:lower()
    for i, item in ipairs(info) do
        if item.name:lower():find(q, 1, true) or item.desc:lower():find(q, 1, true) then
            results[#results + 1] = voltic.result({
                id = item.id,
                name = item.name,
                description = item.desc,
                score = 300 - i,
                meta = { value = item.meta_val or item.name },
            })
        end
    end
    return results
end

function on_action(result, action)
    local value = result.meta and result.meta.value or result.name or "?"
    return "copy:" .. value
end

function on_actions(result)
    return {
        { key = "RET", label = "copy value" },
    }
end
