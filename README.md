# Voltic Plugin Registry

Official plugin registry for [Voltic](https://github.com/drvcvt/voltic), an ultra-fast app launcher for Windows.

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
