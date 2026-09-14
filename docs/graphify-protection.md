# Graphify Protection in Firstmate

This document explains how firstmate prevents agents from loading graphify artifacts directly into context, ensuring they use the graphify CLI instead.

## Why This Matters

Graphify outputs (`graphify-out/`, `graph.json`, `.graphify_*`) are large generated artifacts. Loading them directly into context:
- Wastes tokens (these files can be MB in size)
- Pollutes context with raw data instead of structured queries
- Defeats the purpose of the knowledge graph

Agents should always use:
- `graphify query "<question>"` for architecture, relationships, project structure
- `graphify explain "<concept>"` for definitions and connections
- `graphify god-nodes` for architectural hubs
- `graphify path A B` to trace connections between symbols
- `graphify affected "Symbol"` for impact analysis

## Protection Layers

Firstmate implements three layers of protection:

### Layer 1: OpenCode TUI Watcher Exclusions

File: `~/dotfiles/runcom/config/opencode/opencode.jsonc`

```json
"watcher": {
  "ignore": ["**/graphify-out/**", "**/graph.json", "**/.graphify_*"]
}
```

This prevents the OpenCode TUI file watcher from tracking changes to graphify artifacts, reducing noise.

### Layer 2: PreToolUse Hook (fm-graphify-guard.js)

File: `~/dotfiles/runcom/config/opencode/plugins/fm-graphify-guard.js`

This plugin intercepts tool calls before execution and blocks:

**Blocked tools:**
- `read` or `glob` on paths matching:
  - `graphify-out/` or `graphify-out`
  - `graph.json`
  - `.graphify_*`

**Blocked bash commands:**
- Any command that references graphify artifact paths (e.g., `cat graph.json`, `ls graphify-out/`, `grep "pattern" graph.json`)

**Allowed:**
- `graphify query "..."`
- `graphify explain "..."`
- `graphify god-nodes`
- `graphify path A B`
- `graphify affected "Symbol"`
- `graphify extract . --code-only`
- Any command on non-graphify paths

When blocked, the plugin throws an error with this message:
```
graphify guard: do not load graphify artifacts directly. Use `graphify query "<question>"` or `graphify explain "<concept>"` instead.
```

### Layer 3: Brief Enhancement (bin/fm-brief.sh)

File: `/Users/kirubeltadesse/Tools/firstmate/bin/fm-brief.sh`

The crewmate brief includes explicit guidance when graphify is detected:

```
3. Check for a knowledge graph in the project root (`graphify-out/` directory or `graph.json`). When present, prefer querying the knowledge graph over reading raw files:
   `graphify query "<question>"` for architecture, relationships, and project structure.
   `graphify explain "<concept>"` for definitions and connections between concepts.
```

This appears in the Setup section of every brief when the project has graphify artifacts.

## How It Works

1. **Detection**: When a crewmate starts, `fm-graphify-context.sh` checks if the project has graphify artifacts
2. **Brief Generation**: If detected, the brief includes graphify usage hints
3. **Runtime Enforcement**: The `fm-graphify-guard.js` plugin blocks any attempt to load graphify files directly
4. **User Feedback**: Blocked attempts show a clear error message directing the agent to use graphify commands

## Testing

To verify the protection works:

```bash
# This should be blocked:
cd ~/projects/mobile-app
echo '{"jsonrpc":"2.0","method":"tools/call","params":{"name":"read","arguments":{"filePath":"graph.json"}}}' | some-mcp-client

# This should be allowed:
cd ~/projects/mobile-app
graphify query "How does authentication work?"
```

## Maintenance

When adding new graphify artifacts or changing the structure:

1. Update the patterns in `fm-graphify-guard.js` if needed
2. Update the watcher ignore list in `opencode.jsonc`
3. Update `fm-graphify-context.sh` if new artifact locations are introduced

## Related Files

- `bin/fm-graphify-context.sh` - Detects graphify presence
- `bin/fm-graphify-refresh.sh` - Refreshes the knowledge graph
- `bin/fm-graphify-launchd.sh` - macOS launchd integration for auto-refresh
- `bin/fm-graphify-pmset.sh` - Power management integration