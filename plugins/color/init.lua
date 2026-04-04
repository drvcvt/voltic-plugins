local voltic = require("voltic")

voltic.register({
    name = "color",
    prefix = "co",
    description = "Color converter",
})

-- ── Conversion helpers ──

local function clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

local function rgb_to_hex(r, g, b)
    return string.format("#%02x%02x%02x", clamp(r, 0, 255), clamp(g, 0, 255), clamp(b, 0, 255))
end

local function rgb_to_hsl(r, g, b)
    r, g, b = r / 255, g / 255, b / 255
    local max = math.max(r, g, b)
    local min = math.min(r, g, b)
    local l = (max + min) / 2
    if max == min then
        return 0, 0, l
    end
    local d = max - min
    local s = l > 0.5 and d / (2 - max - min) or d / (max + min)
    local h
    if max == r then
        h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then
        h = (b - r) / d + 2
    else
        h = (r - g) / d + 4
    end
    h = h / 6
    return math.floor(h * 360 + 0.5), math.floor(s * 100 + 0.5), math.floor(l * 100 + 0.5)
end

local function hsl_to_rgb(h, s, l)
    h, s, l = h / 360, s / 100, l / 100
    if s == 0 then
        local v = math.floor(l * 255 + 0.5)
        return v, v, v
    end
    local function hue2rgb(p, q, t)
        if t < 0 then t = t + 1 end
        if t > 1 then t = t - 1 end
        if t < 1/6 then return p + (q - p) * 6 * t end
        if t < 1/2 then return q end
        if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
        return p
    end
    local q = l < 0.5 and l * (1 + s) or l + s - l * s
    local p = 2 * l - q
    return math.floor(hue2rgb(p, q, h + 1/3) * 255 + 0.5),
           math.floor(hue2rgb(p, q, h) * 255 + 0.5),
           math.floor(hue2rgb(p, q, h - 1/3) * 255 + 0.5)
end

-- ── Parsers ──

local function parse_hex(s)
    -- #rgb, #rrggbb
    local short = s:match("^#?(%x%x%x)$")
    if short then
        local r = tonumber(short:sub(1,1), 16) * 17
        local g = tonumber(short:sub(2,2), 16) * 17
        local b = tonumber(short:sub(3,3), 16) * 17
        return r, g, b
    end
    local full = s:match("^#?(%x%x%x%x%x%x)$")
    if full then
        return tonumber(full:sub(1,2), 16), tonumber(full:sub(3,4), 16), tonumber(full:sub(5,6), 16)
    end
    return nil
end

local function parse_rgb(s)
    local r, g, b = s:match("^rgb%s*%((%d+)%s*[,/]%s*(%d+)%s*[,/]%s*(%d+)%s*%)$")
    if not r then
        r, g, b = s:match("^(%d+)%s*[,/]%s*(%d+)%s*[,/]%s*(%d+)$")
    end
    if r then return tonumber(r), tonumber(g), tonumber(b) end
    return nil
end

local function parse_hsl(s)
    local h, ss, l = s:match("^hsl%s*%((%d+)%s*[,/]%s*(%d+)%%?%s*[,/]%s*(%d+)%%?%s*%)$")
    if not h then
        h, ss, l = s:match("^(%d+)%s+(%d+)%%?%s+(%d+)%%?$")
    end
    if h then return tonumber(h), tonumber(ss), tonumber(l) end
    return nil
end

-- ── Search ──

function on_search(query)
    query = query:match("^%s*(.-)%s*$") or query

    if query == "" then
        return {
            voltic.result({
                id = "hint",
                name = "Type a color to convert",
                description = "#ff5733, rgb(255,87,51), hsl(11,100,60), ff5733",
                score = 100,
            }),
        }
    end

    local q = query:lower()
    local results = {}

    -- Try hex
    local r, g, b = parse_hex(q)
    local source = "hex"

    -- Try rgb
    if not r then
        r, g, b = parse_rgb(q)
        source = "rgb"
    end

    -- Try hsl
    if not r then
        local h, s, l = parse_hsl(q)
        if h then
            r, g, b = hsl_to_rgb(h, s, l)
            source = "hsl"
        end
    end

    if not r then
        return {
            voltic.result({
                id = "invalid",
                name = "Not a recognized color format",
                description = "Try: #ff5733, rgb(255,87,51), hsl(11,100,60)",
                score = 100,
            }),
        }
    end

    r = clamp(r, 0, 255)
    g = clamp(g, 0, 255)
    b = clamp(b, 0, 255)

    local hex = rgb_to_hex(r, g, b)
    local h, s, l = rgb_to_hsl(r, g, b)
    local rgb_str = string.format("rgb(%d, %d, %d)", r, g, b)
    local hsl_str = string.format("hsl(%d, %d%%, %d%%)", h, s, l)

    results[#results + 1] = voltic.result({
        id = "hex",
        name = hex,
        description = "HEX" .. (source == "hex" and " (input)" or ""),
        score = 300,
        meta = { value = hex },
    })
    results[#results + 1] = voltic.result({
        id = "rgb",
        name = rgb_str,
        description = "RGB" .. (source == "rgb" and " (input)" or ""),
        score = 290,
        meta = { value = rgb_str },
    })
    results[#results + 1] = voltic.result({
        id = "hsl",
        name = hsl_str,
        description = "HSL" .. (source == "hsl" and " (input)" or ""),
        score = 280,
        meta = { value = hsl_str },
    })

    -- CSS variable format
    local css_var = string.format("%d %d%% %d%%", h, s, l)
    results[#results + 1] = voltic.result({
        id = "oklch",
        name = css_var,
        description = "HSL (CSS shorthand)",
        score = 270,
        meta = { value = css_var },
    })

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
