# Voltic Plugin Registry

Official plugin registry for [Voltic](https://github.com/drvcvt/voltic), an ultra-fast app launcher for Windows.

## Official Plugins

### Utility

| Prefix | Name | Description |
|--------|------|-------------|
| `hh` | **hash** | Hash, encode & decode text. Base64, URL encode/decode, hex conversion, DJB2 hash, and character count. Type any text to see all encodings at once. |
| `uu` | **uuid** | Generate UUIDs, random hex, base64, and alphanumeric strings. `uu` for a single UUID, `uu 5` for five, `uu hex 32` for a random hex string, `uu b64 24` for base64. |
| `co` | **color** | Convert colors between hex, RGB, and HSL. Accepts `#ff5733`, `rgb(255,87,51)`, `hsl(11,100,60)`, or bare hex like `ff5733`. Shows all formats plus CSS shorthand. |
| `pw` | **pass** | Generate secure passwords and passphrases. `pw` for defaults, `pw 32` for 32 chars, `pw pin` for numeric PIN, `pw phrase 5` for a 5-word passphrase. Shows entropy bits for each option. |

### Developer Tools

| Prefix | Name | Description |
|--------|------|-------------|
| `ep` | **epoch** | Convert between Unix timestamps and human-readable dates. `ep` shows current time, `ep 1700000000` converts to date, `ep 2024-01-15 14:30:00` converts to timestamp. Shows relative time ("3d 5h ago"). Handles millisecond timestamps automatically. |
| `jf` | **json** | Format, minify, and validate JSON. Paste any JSON to get prettified output, minified version, validation status, and structure stats (keys, values, objects, arrays). Auto-fixes single-quote JSON. |
| `pt` | **port** | Show all listening TCP ports and their processes. `pt` lists everything, `pt 3000` finds a specific port, `pt node` filters by process name. Enter to kill the process on a port. |
| `pk` | **proc** | Search and kill running processes. `pk` shows top 15 by memory, `pk chrome` filters by name. Shows PID and memory usage. Enter to kill, Ctrl+Enter to copy PID. |

### Productivity

| Prefix | Name | Description |
|--------|------|-------------|
| `qn` | **notes** | Quick notes -- save and search text snippets. `qn add meeting at 3pm` to save, `qn` to list all, `qn meeting` to search, `qn del` to delete. Notes persist across sessions. |
| `tm` | **timer** | Timers and stopwatches. `tm 5m` starts a 5-minute timer, `tm 30s` for 30 seconds, `tm stopwatch` to count up, `tm status` to check running timers. Named timers: `tm meeting 25m`. |

### Search & Web

| Prefix | Name | Description |
|--------|------|-------------|
| `ws` | **web-search** | Search the web with 10 engines. `ws rust async` searches all, `ws g rust async` uses Google, `ws gh tauri` searches GitHub, `ws yt tutorial` opens YouTube. Engines: Google, DuckDuckGo, YouTube, GitHub, Reddit, Wikipedia, npm, crates.io, Stack Overflow, Google Maps. |
| `df` | **define** | English dictionary -- look up word definitions via the Free Dictionary API. Shows pronunciation, definitions by part of speech (up to 3 each), example sentences, and synonyms. Results are cached for 1 hour. |

### System & Network

| Prefix | Name | Description |
|--------|------|-------------|
| `sys` | **sysinfo** | System information at a glance. Shows RAM usage, CPU model, disk space per drive, local IP, uptime, and top 5 processes by memory. Results cached for 10 seconds. |
| `ip` | **ip** | Show public and local IP addresses, geolocation, ISP, and timezone. `ip` for your own info, `ip 8.8.8.8` to look up any IP. Uses ipify.org and ipinfo.io. |

## Installing Plugins

From the Voltic launcher:
```
:plugin install <name>
```

Or via CLI:
```
voltic plugin install <name>
```

Or browse and install from **Settings > Plugins**.

## Plugin Structure

Each plugin lives in its own Git repository with this structure:
```
my-plugin/
  plugin.toml    # Manifest (required)
  init.lua       # Entry point (required)
  README.md      # Documentation
```

### plugin.toml
```toml
[plugin]
name = "my-plugin"
version = "0.1.0"
description = "What my plugin does"
author = "yourname"
prefix = "mp"

[permissions]
http = ["api.example.com"]
# fs = ["/some/path"]
# clipboard = true
# exec = true
```

### init.lua
```lua
function on_search(query)
    return {
        voltic.result({
            id = "my-plugin:example",
            name = "Example Result",
            description = "This is an example",
        })
    }
end
```

## Submitting a Plugin

1. Create your plugin repo with the structure above
2. Fork this registry repo
3. Add your plugin entry to `registry.json`:
```json
{
  "name": "my-plugin",
  "description": "What my plugin does",
  "author": "yourname",
  "version": "0.1.0",
  "prefix": "mp",
  "repo": "https://github.com/yourname/voltic-plugin-my-plugin",
  "permissions": ["http"],
  "tags": ["search", "productivity"]
}
```
4. Open a Pull Request

### Requirements
- Plugin name: lowercase, hyphens only (`^[a-z0-9-]+$`)
- Prefix: 2+ characters, must not collide with built-in prefixes (`! @ > = : / ; # $ ? w`)
- Version: semver (`x.y.z`)
- Repo must be public and contain `plugin.toml` + `init.lua`

## Third-Party Registries

Voltic supports custom registries. Users can add additional registry URLs in Settings to discover plugins from other sources.

## API

Voltic fetches `registry.json` from the `main` branch:
```
https://raw.githubusercontent.com/drvcvt/voltic-plugins/main/registry.json
```

## License

Registry metadata is public domain. Individual plugins are licensed by their respective authors.
