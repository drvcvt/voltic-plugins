local voltic = require("voltic")

voltic.register({
    name = "unit",
    prefix = "un",
    description = "Unit converter",
})

-- Unit definitions: base unit per category, conversion factor to base
local CATEGORIES = {
    length = {
        base = "m",
        units = {
            mm = 0.001, cm = 0.01, m = 1, km = 1000,
            ["in"] = 0.0254, inch = 0.0254, inches = 0.0254,
            ft = 0.3048, foot = 0.3048, feet = 0.3048,
            yd = 0.9144, yard = 0.9144, yards = 0.9144,
            mi = 1609.344, mile = 1609.344, miles = 1609.344,
            nm = 0.000000001, ["nmi"] = 1852,
        },
    },
    weight = {
        base = "g",
        units = {
            mg = 0.001, g = 1, kg = 1000, t = 1000000,
            oz = 28.3495, ounce = 28.3495,
            lb = 453.592, lbs = 453.592, pound = 453.592, pounds = 453.592,
            st = 6350.29, stone = 6350.29,
        },
    },
    data = {
        base = "B",
        units = {
            b = 0.125, bit = 0.125, bits = 0.125,
            B = 1, byte = 1, bytes = 1,
            KB = 1000, MB = 1e6, GB = 1e9, TB = 1e12, PB = 1e15,
            KiB = 1024, MiB = 1048576, GiB = 1073741824, TiB = 1099511627776,
            kb = 1000, mb = 1e6, gb = 1e9, tb = 1e12,
        },
    },
    time = {
        base = "s",
        units = {
            ms = 0.001, s = 1, sec = 1, secs = 1, second = 1, seconds = 1,
            min = 60, mins = 60, minute = 60, minutes = 60,
            h = 3600, hr = 3600, hrs = 3600, hour = 3600, hours = 3600,
            d = 86400, day = 86400, days = 86400,
            w = 604800, wk = 604800, week = 604800, weeks = 604800,
            mo = 2629800, month = 2629800, months = 2629800,
            y = 31557600, yr = 31557600, year = 31557600, years = 31557600,
        },
    },
    speed = {
        base = "m/s",
        units = {
            ["m/s"] = 1, ["km/h"] = 0.277778, kph = 0.277778,
            ["mph"] = 0.44704, ["mi/h"] = 0.44704,
            kt = 0.514444, knot = 0.514444, knots = 0.514444,
        },
    },
}

-- Temperature needs special handling (not linear)
local function convert_temp(value, from, to)
    from = from:lower()
    to = to:lower()
    -- Normalize to Celsius
    local c
    if from == "c" or from == "celsius" then
        c = value
    elseif from == "f" or from == "fahrenheit" then
        c = (value - 32) * 5 / 9
    elseif from == "k" or from == "kelvin" then
        c = value - 273.15
    else
        return nil
    end
    -- Convert from Celsius
    if to == "c" or to == "celsius" then
        return c
    elseif to == "f" or to == "fahrenheit" then
        return c * 9 / 5 + 32
    elseif to == "k" or to == "kelvin" then
        return c + 273.15
    end
    return nil
end

local function is_temp_unit(u)
    u = u:lower()
    return u == "c" or u == "celsius" or u == "f" or u == "fahrenheit" or u == "k" or u == "kelvin"
end

local function find_category(unit)
    for cat_name, cat in pairs(CATEGORIES) do
        if cat.units[unit] then
            return cat_name, cat
        end
    end
    return nil, nil
end

local function convert(value, from, to)
    -- Temperature special case
    if is_temp_unit(from) and is_temp_unit(to) then
        return convert_temp(value, from, to)
    end

    local cat_from, cat_data = find_category(from)
    if not cat_data then return nil end
    if not cat_data.units[to] then return nil end

    local base_value = value * cat_data.units[from]
    return base_value / cat_data.units[to]
end

local function format_number(n)
    if n == math.floor(n) and math.abs(n) < 1e15 then
        return string.format("%.0f", n)
    end
    -- Show up to 6 significant digits, trim trailing zeros
    local s = string.format("%.6g", n)
    return s
end

-- Parse: "100 km to miles" | "100 km miles" | "100km miles"
local function parse_query(q)
    -- Try "value from to unit_to" format with "to"/"in"/"as"
    local v, f, t = q:match("^([%-%d.]+)%s*([%a%/%^]+)%s+to%s+([%a%/%^]+)$")
    if not v then v, f, t = q:match("^([%-%d.]+)%s*([%a%/%^]+)%s+in%s+([%a%/%^]+)$") end
    if not v then v, f, t = q:match("^([%-%d.]+)%s*([%a%/%^]+)%s+as%s+([%a%/%^]+)$") end
    if not v then v, f, t = q:match("^([%-%d.]+)%s*([%a%/%^]+)%s+([%a%/%^]+)$") end
    if not v then v, f = q:match("^([%-%d.]+)%s*([%a%/%^]+)$") end

    local value = tonumber(v)
    if not value then return nil end
    return value, f, t
end

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query

    if query == "" then
        return {
            voltic.result({
                id = "hint",
                name = "Type a conversion",
                description = "un 100 km miles | un 25 c f | un 5 GB MB | un 72 kg lb",
                score = 100,
            }),
        }
    end

    local value, from, to = parse_query(query)
    if not value or not from then
        return {
            voltic.result({
                id = "invalid",
                name = "Invalid format",
                description = "Try: un 100 km miles | un 25 c f",
                score = 100,
            }),
        }
    end

    local results = {}

    if to then
        -- Single target unit
        local converted = convert(value, from, to)
        if converted then
            results[#results + 1] = voltic.result({
                id = "conv",
                name = string.format("%s %s = %s %s", format_number(value), from, format_number(converted), to),
                description = "Converted value",
                score = 300,
                meta = { value = format_number(converted) },
            })
        else
            results[#results + 1] = voltic.result({
                id = "err",
                name = "Can't convert " .. from .. " to " .. to,
                description = "Units must be in the same category",
                score = 100,
            })
        end
        return results
    end

    -- No target unit: show all same-category conversions
    if is_temp_unit(from) then
        local targets = {"C", "F", "K"}
        local from_upper = from:upper()
        for i, t in ipairs(targets) do
            if t ~= from_upper:sub(1, 1) then
                local c = convert_temp(value, from, t)
                if c then
                    results[#results + 1] = voltic.result({
                        id = "to_" .. t,
                        name = string.format("%s %s = %s %s", format_number(value), from:upper(), format_number(c), t),
                        description = "Temperature",
                        score = 300 - i,
                        meta = { value = format_number(c) },
                    })
                end
            end
        end
        return results
    end

    local cat_name, cat_data = find_category(from)
    if not cat_data then
        return {
            voltic.result({
                id = "unknown",
                name = "Unknown unit: " .. from,
                description = "Supported: length, weight, data, time, speed, temperature",
                score = 100,
            }),
        }
    end

    -- Show conversions to common units in the same category
    local common = {
        length = {"km", "m", "cm", "mi", "ft", "inch"},
        weight = {"kg", "g", "lb", "oz"},
        data = {"GB", "MB", "KB", "GiB", "MiB", "KiB"},
        time = {"s", "min", "h", "d", "w"},
        speed = {"km/h", "m/s", "mph", "kt"},
    }

    local targets = common[cat_name] or {}
    local idx = 300
    for _, t in ipairs(targets) do
        if t ~= from then
            local converted = convert(value, from, t)
            if converted then
                results[#results + 1] = voltic.result({
                    id = "to_" .. t,
                    name = string.format("%s %s = %s %s", format_number(value), from, format_number(converted), t),
                    description = cat_name,
                    score = idx,
                    meta = { value = format_number(converted) },
                })
                idx = idx - 10
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
        return {{ key = "RET", label = "copy result" }}
    end
    return {{ key = "RET", label = "select" }}
end
