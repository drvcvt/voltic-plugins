local voltic = require("voltic")

voltic.register({
    name = "timer",
    prefix = "tm",
    description = "Timers and stopwatches",
})

-- We can't access os.time() (sandboxed), so we use a trick:
-- Store a "epoch probe" in cache with a known TTL, then measure
-- how much TTL remains to derive elapsed time. For timers we store
-- the target duration and a cache key that expires when the timer ends.
--
-- Approach: voltic.cache.set stores real SystemTime expiry on the Rust side.
-- We set a cache entry with TTL = timer_duration. If cache.get returns
-- non-nil, the timer is still running. The remaining time can be approximated
-- by storing the total duration and checking presence of sub-keys with
-- decreasing TTLs (resolution markers).
--
-- Simpler approach: store start info, use a "tick" key that we refresh each
-- search to track approximate elapsed seconds via a counter.
--
-- Simplest practical approach: store duration_seconds in cache with that exact
-- TTL. Timer is "running" if the key exists. For remaining time display, we
-- also store the duration and use a parallel "elapsed tracker" -- a key that
-- we set with TTL=1 each search call, counting how many times it expired.
--
-- Actually the cleanest way: store the timer with TTL = duration. When the
-- key is gone, the timer has expired. For showing remaining time, also store
-- a "start_tick" counter that increments each on_search call and a total
-- duration. Since searches happen frequently when the window is open, this
-- gives a reasonable approximation. For precision, we'll store multiple
-- checkpoint keys with staggered TTLs.

-- Timer storage format in cache:
--   timer:<id>:active   = "1"  (TTL = duration_seconds)  -- presence = running
--   timer:<id>:name     = name (TTL = duration + 3600)    -- metadata
--   timer:<id>:duration = secs (TTL = duration + 3600)    -- total duration
--   timer:<id>:check_N  = "1"  (TTL = N seconds)         -- checkpoint every 10s

local MAX_TIMERS = 10
local MAX_CHECKPOINTS = 360 -- up to 1 hour of 10s checkpoints

local function get_timer_ids()
    local raw = voltic.cache.get("timer:ids")
    if not raw then return {} end
    local ok, ids = pcall(voltic.json.decode, raw)
    if not ok then return {} end
    return ids
end

local function save_timer_ids(ids)
    voltic.cache.set("timer:ids", voltic.json.encode(ids), 86400)
end

local function parse_duration(input)
    -- "5m" / "5min" -> 300, "30s" -> 30, "1h" -> 3600, "90" -> 90 (seconds), "5" -> 300 (minutes)
    local num, unit = input:match("^(%d+)%s*(%a*)")
    if not num then return nil end
    num = tonumber(num)
    if not num or num <= 0 then return nil end

    unit = unit:lower()
    if unit == "h" or unit == "hr" or unit == "hrs" or unit == "hour" or unit == "hours" then
        return num * 3600
    elseif unit == "m" or unit == "min" or unit == "mins" or unit == "minute" or unit == "minutes" then
        return num * 60
    elseif unit == "s" or unit == "sec" or unit == "secs" or unit == "second" or unit == "seconds" then
        return num
    elseif unit == "" then
        -- Bare number: if <= 120, treat as minutes; otherwise seconds
        if num <= 120 then
            return num * 60
        else
            return num
        end
    end
    return nil
end

local function format_duration(seconds)
    if seconds <= 0 then return "0s" end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = seconds % 60
    if h > 0 then
        return string.format("%dh %dm %ds", h, m, s)
    elseif m > 0 then
        return string.format("%dm %ds", m, s)
    else
        return string.format("%ds", s)
    end
end

local function start_timer(name, duration_secs)
    local ids = get_timer_ids()

    -- Find next available ID
    local id = 1
    for _, existing in ipairs(ids) do
        if existing >= id then id = existing + 1 end
    end
    if #ids >= MAX_TIMERS then
        return nil, "max " .. MAX_TIMERS .. " timers"
    end

    -- Store the timer
    voltic.cache.set("timer:" .. id .. ":active", "1", duration_secs)
    voltic.cache.set("timer:" .. id .. ":name", name, duration_secs + 3600)
    voltic.cache.set("timer:" .. id .. ":duration", tostring(duration_secs), duration_secs + 3600)

    -- Create checkpoint keys for remaining-time estimation
    -- Every 10 seconds up to the duration
    local step = 10
    if duration_secs <= 60 then step = 5 end
    if duration_secs <= 10 then step = 1 end
    local checkpoints = math.min(math.floor(duration_secs / step), MAX_CHECKPOINTS)
    voltic.cache.set("timer:" .. id .. ":step", tostring(step), duration_secs + 3600)
    voltic.cache.set("timer:" .. id .. ":checkpoints", tostring(checkpoints), duration_secs + 3600)
    for c = 1, checkpoints do
        voltic.cache.set("timer:" .. id .. ":cp_" .. c, "1", c * step)
    end

    ids[#ids + 1] = id
    save_timer_ids(ids)
    return id
end

local function get_remaining(id)
    local active = voltic.cache.get("timer:" .. id .. ":active")
    if not active then return nil end -- expired

    local duration = tonumber(voltic.cache.get("timer:" .. id .. ":duration")) or 0
    local step = tonumber(voltic.cache.get("timer:" .. id .. ":step")) or 10
    local checkpoints = tonumber(voltic.cache.get("timer:" .. id .. ":checkpoints")) or 0

    -- Find the highest expired checkpoint to estimate elapsed time
    -- Checkpoint c was set with TTL = c * step
    -- If cp_c is nil, at least c*step seconds have passed
    local elapsed_estimate = 0
    for c = checkpoints, 1, -1 do
        local cp = voltic.cache.get("timer:" .. id .. ":cp_" .. c)
        if cp then
            -- This checkpoint hasn't expired yet, so elapsed < c * step
            -- The previous one (c+1) expired, so elapsed >= (c+1-1)*step... no wait
            -- cp_c has TTL = c*step, meaning it expires c*step seconds after start
            -- if cp_c exists, less than c*step seconds have passed
            -- if cp_c is nil, at least c*step seconds have passed
            -- We want the lowest c where cp_c still exists
            elapsed_estimate = (c - 1) * step
            break
        else
            elapsed_estimate = c * step
        end
    end

    local remaining = math.max(0, duration - elapsed_estimate)
    return remaining
end

local function cancel_timer(id)
    voltic.cache.set("timer:" .. id .. ":active", nil, 0)
    -- Remove from ids list
    local ids = get_timer_ids()
    local new_ids = {}
    for _, v in ipairs(ids) do
        if v ~= id then new_ids[#new_ids + 1] = v end
    end
    save_timer_ids(new_ids)
end

local function get_all_timers()
    local ids = get_timer_ids()
    local timers = {}
    local active_ids = {}

    for _, id in ipairs(ids) do
        local active = voltic.cache.get("timer:" .. id .. ":active")
        local name = voltic.cache.get("timer:" .. id .. ":name") or ("Timer " .. id)
        local duration = tonumber(voltic.cache.get("timer:" .. id .. ":duration")) or 0

        if active then
            local remaining = get_remaining(id)
            timers[#timers + 1] = {
                id = id,
                name = name,
                duration = duration,
                remaining = remaining or 0,
                done = false,
            }
            active_ids[#active_ids + 1] = id
        else
            -- Timer expired but we still have metadata
            if voltic.cache.get("timer:" .. id .. ":name") then
                timers[#timers + 1] = {
                    id = id,
                    name = name,
                    duration = duration,
                    remaining = 0,
                    done = true,
                }
                active_ids[#active_ids + 1] = id
            end
            -- else: fully expired (metadata gone too), skip
        end
    end

    -- Clean up ids list
    if #active_ids ~= #ids then
        save_timer_ids(active_ids)
    end

    return timers
end

-- Stopwatch: uses cache counter approach
-- Each search increments a counter. Not accurate, but shows elapsed conceptually.
-- Better: store a "stopwatch started" flag, and use checkpoint TTLs in reverse
-- (set a very long TTL key, then use checkpoints to measure how long ago it started)

local function start_stopwatch(name)
    local ids = get_timer_ids()
    local id = 1
    for _, existing in ipairs(ids) do
        if existing >= id then id = existing + 1 end
    end

    local max_duration = 86400 -- 24 hours max
    voltic.cache.set("timer:" .. id .. ":active", "1", max_duration)
    voltic.cache.set("timer:" .. id .. ":name", name or "Stopwatch", max_duration + 3600)
    voltic.cache.set("timer:" .. id .. ":duration", "0", max_duration + 3600) -- 0 = stopwatch mode
    voltic.cache.set("timer:" .. id .. ":stopwatch", "1", max_duration + 3600)

    -- Checkpoints: set keys that expire at known intervals to measure elapsed time
    local step = 5
    local checkpoints = math.min(math.floor(max_duration / step), MAX_CHECKPOINTS)
    voltic.cache.set("timer:" .. id .. ":step", tostring(step), max_duration + 3600)
    voltic.cache.set("timer:" .. id .. ":checkpoints", tostring(checkpoints), max_duration + 3600)
    for c = 1, checkpoints do
        voltic.cache.set("timer:" .. id .. ":cp_" .. c, "1", c * step)
    end

    ids[#ids + 1] = id
    save_timer_ids(ids)
    return id
end

local function get_stopwatch_elapsed(id)
    local step = tonumber(voltic.cache.get("timer:" .. id .. ":step")) or 5
    local checkpoints = tonumber(voltic.cache.get("timer:" .. id .. ":checkpoints")) or 0

    -- Find the highest c where cp_c has expired
    local elapsed = 0
    for c = 1, checkpoints do
        local cp = voltic.cache.get("timer:" .. id .. ":cp_" .. c)
        if not cp then
            elapsed = c * step
        else
            break
        end
    end
    return elapsed
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query -- trim

    -- Empty query: show menu + active timers
    if query == "" then
        local results = {}
        results[#results + 1] = voltic.result({
            id = "new_timer",
            name = "Start a timer",
            description = "Type duration: tm 5m, tm 30s, tm 1h, tm 90",
            score = 300,
            meta = { action = "hint" },
        })
        results[#results + 1] = voltic.result({
            id = "new_stopwatch",
            name = "Start stopwatch",
            description = "Press Enter to start counting up",
            score = 290,
            meta = { action = "start_stopwatch" },
        })

        -- Show active timers
        local timers = get_all_timers()
        for _, t in ipairs(timers) do
            local is_sw = voltic.cache.get("timer:" .. t.id .. ":stopwatch")
            if t.done then
                results[#results + 1] = voltic.result({
                    id = "timer_" .. t.id,
                    name = t.name .. " -- DONE!",
                    description = "Finished (" .. format_duration(t.duration) .. "). Enter to dismiss.",
                    score = 280,
                    meta = { timer_id = t.id, action = "dismiss" },
                })
            elseif is_sw then
                local elapsed = get_stopwatch_elapsed(t.id)
                results[#results + 1] = voltic.result({
                    id = "timer_" .. t.id,
                    name = t.name .. " -- " .. format_duration(elapsed),
                    description = "Running. Enter to stop & copy elapsed time.",
                    score = 270,
                    meta = { timer_id = t.id, elapsed = format_duration(elapsed), action = "stop_sw" },
                })
            else
                results[#results + 1] = voltic.result({
                    id = "timer_" .. t.id,
                    name = t.name .. " -- " .. format_duration(t.remaining) .. " left",
                    description = format_duration(t.duration) .. " total. Enter to cancel.",
                    score = 270,
                    meta = { timer_id = t.id, remaining = format_duration(t.remaining), action = "cancel" },
                })
            end
        end

        return results
    end

    -- "status" -> show all timers
    if query == "status" or query == "list" then
        local timers = get_all_timers()
        if #timers == 0 then
            return {
                voltic.result({
                    id = "no_timers",
                    name = "No active timers",
                    description = "Start one with tm 5m",
                    score = 200,
                }),
            }
        end

        local results = {}
        for _, t in ipairs(timers) do
            local is_sw = voltic.cache.get("timer:" .. t.id .. ":stopwatch")
            if t.done then
                results[#results + 1] = voltic.result({
                    id = "timer_" .. t.id,
                    name = t.name .. " -- DONE!",
                    description = "Finished. Enter to dismiss.",
                    score = 280,
                    meta = { timer_id = t.id, action = "dismiss" },
                })
            elseif is_sw then
                local elapsed = get_stopwatch_elapsed(t.id)
                results[#results + 1] = voltic.result({
                    id = "timer_" .. t.id,
                    name = t.name .. " -- " .. format_duration(elapsed),
                    description = "Stopwatch running. Enter to stop.",
                    score = 270,
                    meta = { timer_id = t.id, elapsed = format_duration(elapsed), action = "stop_sw" },
                })
            else
                results[#results + 1] = voltic.result({
                    id = "timer_" .. t.id,
                    name = t.name .. " -- " .. format_duration(t.remaining) .. " left",
                    description = format_duration(t.duration) .. " total. Enter to cancel.",
                    score = 270,
                    meta = { timer_id = t.id, remaining = format_duration(t.remaining), action = "cancel" },
                })
            end
        end
        return results
    end

    -- "stop" or "cancel" -> cancel all or specific
    if query == "stop" or query == "cancel" or query == "clear" then
        local timers = get_all_timers()
        if #timers == 0 then
            return {
                voltic.result({
                    id = "no_timers",
                    name = "No active timers to cancel",
                    score = 200,
                }),
            }
        end
        local results = {}
        for _, t in ipairs(timers) do
            results[#results + 1] = voltic.result({
                id = "cancel_" .. t.id,
                name = "Cancel: " .. t.name,
                description = "Press Enter to cancel this timer",
                score = 250,
                meta = { timer_id = t.id, action = "cancel" },
            })
        end
        return results
    end

    -- "sw" or "stopwatch" -> start a stopwatch
    if query == "sw" or query == "stopwatch" then
        return {
            voltic.result({
                id = "new_stopwatch",
                name = "Start stopwatch",
                description = "Press Enter to start counting up",
                score = 300,
                meta = { action = "start_stopwatch" },
            }),
        }
    end

    -- Try to parse as duration -> offer to start timer
    local duration = parse_duration(query)
    if duration then
        local label = format_duration(duration)
        return {
            voltic.result({
                id = "start_timer",
                name = "Start timer: " .. label,
                description = "Press Enter to start a " .. label .. " timer",
                score = 300,
                meta = { action = "start_timer", duration = duration, label = label },
            }),
        }
    end

    -- Named timer: "meeting 25m" pattern
    local tname, tdur = query:match("^(.-)%s+(%d+%s*%a*)$")
    if tname and tdur then
        local d = parse_duration(tdur)
        if d then
            local label = format_duration(d)
            return {
                voltic.result({
                    id = "start_named",
                    name = "Start '" .. tname .. "' timer: " .. label,
                    description = "Press Enter to start",
                    score = 300,
                    meta = { action = "start_timer", duration = d, label = label, timer_name = tname },
                }),
            }
        end
    end

    return {
        voltic.result({
            id = "help",
            name = "Timer help",
            description = "tm 5m | tm 30s | tm 1h | tm status | tm stopwatch",
            score = 100,
        }),
    }
end

function on_action(result, action)
    if not result.meta then return end
    local meta = result.meta

    if meta.action == "start_timer" then
        local duration = meta.duration
        if not duration then return end
        local name = meta.timer_name or ("Timer " .. meta.label)
        local id, err = start_timer(name, math.floor(duration))
        if id then
            voltic.log.info("started timer '" .. name .. "' for " .. format_duration(duration))
        else
            voltic.log.error("failed to start timer: " .. (err or "unknown"))
        end
        return

    elseif meta.action == "start_stopwatch" then
        local id = start_stopwatch("Stopwatch")
        voltic.log.info("started stopwatch #" .. id)
        return

    elseif meta.action == "cancel" or meta.action == "dismiss" then
        local tid = meta.timer_id
        if tid then
            cancel_timer(tid)
            voltic.log.info("cancelled timer #" .. tid)
        end
        return

    elseif meta.action == "stop_sw" then
        local tid = meta.timer_id
        if tid then
            local elapsed = meta.elapsed or "?"
            cancel_timer(tid)
            voltic.log.info("stopped stopwatch: " .. elapsed)
            return "copy:" .. elapsed
        end
        return

    elseif meta.action == "hint" then
        return
    end

    -- Default: copy remaining/elapsed time
    if meta.remaining then
        return "copy:" .. meta.remaining
    end
    if meta.elapsed then
        return "copy:" .. meta.elapsed
    end
end

function on_actions(result)
    if not result.meta then
        return {{ key = "RET", label = "select" }}
    end

    local meta = result.meta
    if meta.action == "start_timer" then
        return {{ key = "RET", label = "start timer" }}
    elseif meta.action == "start_stopwatch" then
        return {{ key = "RET", label = "start stopwatch" }}
    elseif meta.action == "cancel" then
        return {{ key = "RET", label = "cancel timer" }}
    elseif meta.action == "dismiss" then
        return {{ key = "RET", label = "dismiss" }}
    elseif meta.action == "stop_sw" then
        return {{ key = "RET", label = "stop & copy time" }}
    end

    return {{ key = "RET", label = "copy time" }}
end
