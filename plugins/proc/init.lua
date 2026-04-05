local voltic = require("voltic")

voltic.register({
    name = "proc",
    prefix = "pk",
    description = "Process manager",
})

local function trim(s)
    return s:match("^%s*(.-)%s*$") or s
end

local function get_processes(filter)
    local cmd
    if filter and #filter > 0 then
        cmd = 'powershell -NoProfile -Command "Get-Process | Where-Object {$_.ProcessName -like \'*' .. filter .. '*\'} | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 | ForEach-Object { $mem=[math]::Round($_.WorkingSet64/1MB,1); Write-Host (\'{0}|{1}|{2}\' -f $_.Id,$_.ProcessName,$mem) }"'
    else
        cmd = 'powershell -NoProfile -Command "Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 | ForEach-Object { $mem=[math]::Round($_.WorkingSet64/1MB,1); Write-Host (\'{0}|{1}|{2}\' -f $_.Id,$_.ProcessName,$mem) }"'
    end

    local raw = voltic.exec(cmd)
    local procs = {}
    for line in raw:gmatch("[^\r\n]+") do
        local t = trim(line)
        local pid, name, mem = t:match("^(%d+)|(.+)|(.+)$")
        if pid and name then
            procs[#procs + 1] = {
                pid = tonumber(pid),
                name = trim(name),
                mem = trim(mem),
            }
        end
    end
    return procs
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query

    local procs = get_processes(query)
    local results = {}

    if #procs == 0 then
        results[#results + 1] = voltic.result({
            id = "empty",
            name = query == "" and "Loading processes..." or "No processes matching '" .. query .. "'",
            description = "pk <name> to search, Enter to kill",
            score = 100,
        })
        return results
    end

    for i, p in ipairs(procs) do
        results[#results + 1] = voltic.result({
            id = "proc:" .. p.pid,
            name = p.name,
            description = "PID " .. p.pid .. " — " .. p.mem .. " MB",
            score = 300 - i,
            meta = { pid = p.pid, name = p.name },
        })
    end

    return results
end

function on_action(result, action)
    if not result.meta or not result.meta.pid then return end

    if action == "default" or action == "kill" then
        local pid = result.meta.pid
        local name = result.meta.name or "?"
        voltic.exec('taskkill /PID ' .. pid .. ' /F')
        voltic.log.info("killed " .. name .. " (PID " .. pid .. ")")
        return
    end

    if action == "copy" then
        return "copy:" .. tostring(result.meta.pid)
    end
end

function on_actions(result)
    if result.meta and result.meta.pid then
        return {
            { key = "RET", label = "kill process" },
            { key = "C-RET", label = "copy PID" },
        }
    end
    return {{ key = "RET", label = "select" }}
end
