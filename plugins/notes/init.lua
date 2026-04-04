local voltic = require("voltic")

voltic.register({
    name = "notes",
    prefix = "qn",
    description = "Quick notes",
})

-- Notes are stored as JSON in the plugin's own directory
-- The plugin dir is auto-detected from voltic.fs paths
local NOTES_FILE = nil

local function get_notes_file()
    if NOTES_FILE then return NOTES_FILE end
    -- Discover our plugin directory by trying to read plugin.toml
    -- The fs.read for our own dir is always allowed
    local plugin_dir = _VOLTIC_PLUGIN_DIR
    if plugin_dir then
        NOTES_FILE = plugin_dir .. "/notes.json"
    end
    return NOTES_FILE
end

local function load_notes()
    local path = get_notes_file()
    if not path then return {} end

    local ok, content = pcall(voltic.fs.read, path)
    if not ok or not content or #content == 0 then
        return {}
    end

    local ok2, notes = pcall(voltic.json.decode, content)
    if not ok2 then return {} end
    return notes
end

local function save_notes(notes)
    local path = get_notes_file()
    if not path then
        voltic.log.error("cannot determine notes file path")
        return
    end
    local json = voltic.json.encode(notes)
    voltic.fs.write(path, json)
end

local function timestamp()
    -- We don't have os.time, so use a simple counter stored in cache
    local ts = voltic.cache.get("notes_counter")
    if ts then
        ts = tonumber(ts) + 1
    else
        ts = 1
    end
    voltic.cache.set("notes_counter", tostring(ts), 86400)
    return ts
end

function on_search(query)
    local notes = load_notes()

    -- "qn add <text>" — show add option
    local add_match = query:match("^add%s+(.+)$")
    if add_match then
        return {
            voltic.result({
                id = "add",
                name = "Save note: " .. add_match,
                description = "Press Enter to save this note",
                score = 300,
                meta = { action = "add", text = add_match },
            }),
        }
    end

    -- "qn del" or "qn delete" — show notes with delete option
    local del_mode = query:match("^del") ~= nil

    -- Empty query or search query — show/filter notes
    if query == "" or query == "del" or query == "delete" then
        if #notes == 0 then
            return {
                voltic.result({
                    id = "empty",
                    name = "No notes yet",
                    description = "Type 'qn add <text>' to create a note",
                    score = 100,
                }),
            }
        end

        local results = {}
        for i = #notes, 1, -1 do
            local note = notes[i]
            results[#results + 1] = voltic.result({
                id = "note_" .. i,
                name = note.text,
                description = del_mode and "Press Enter to DELETE" or ("Note #" .. i),
                score = 200 + i,
                meta = { index = i, text = note.text, del = del_mode },
            })
        end
        return results
    end

    -- Search notes
    local q = query:lower()
    local results = {}
    for i = #notes, 1, -1 do
        local note = notes[i]
        if note.text:lower():find(q, 1, true) then
            results[#results + 1] = voltic.result({
                id = "note_" .. i,
                name = note.text,
                description = "Note #" .. i,
                score = 200 + i,
                meta = { index = i, text = note.text },
            })
        end
    end

    if #results == 0 then
        -- Offer to create a new note with the search query
        results[#results + 1] = voltic.result({
            id = "add_from_search",
            name = "Save as note: " .. query,
            description = "No matching notes found. Press Enter to save.",
            score = 100,
            meta = { action = "add", text = query },
        })
    end

    return results
end

function on_action(result, action)
    if not result.meta then return end

    if result.meta.action == "add" and result.meta.text then
        -- Add a new note
        local notes = load_notes()
        notes[#notes + 1] = { text = result.meta.text, ts = timestamp() }
        save_notes(notes)
        voltic.log.info("note saved: " .. result.meta.text)
        return
    end

    if result.meta.del and result.meta.index then
        -- Delete a note
        local notes = load_notes()
        local idx = result.meta.index
        if idx >= 1 and idx <= #notes then
            local removed = notes[idx].text
            table.remove(notes, idx)
            save_notes(notes)
            voltic.log.info("note deleted: " .. removed)
        end
        return
    end

    -- Default: copy note text
    if result.meta.text then
        return "copy:" .. result.meta.text
    end
end

function on_actions(result)
    if result.meta and result.meta.del then
        return {
            { key = "RET", label = "delete note" },
        }
    end
    if result.meta and result.meta.action == "add" then
        return {
            { key = "RET", label = "save note" },
        }
    end
    return {
        { key = "RET", label = "copy to clipboard" },
    }
end
