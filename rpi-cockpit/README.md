# RPI Cockpit

A real-time browser dashboard that lets you monitor and steer an RPI (Research-Plan-Implement) agent loop running inside Claude Code.

## Install and build

```bash
cd rpi-cockpit
npm install
npm run build
```

## Register with Claude Code

Copy the example MCP registration file to your project root:

```bash
cp rpi-cockpit/.mcp.json.example .mcp.json
```

This registers the cockpit as an MCP server named `rpi-cockpit`. Claude Code will start it automatically when you open the project.

## Open the dashboard

With the server running, open your browser to:

```
http://127.0.0.1:4399
```

The dashboard updates in real time over WebSocket as the agent calls the cockpit beats.

## Agent instrumentation

See [`agents/cockpit-instructions.md`](agents/cockpit-instructions.md) for the snippet that tells an RPI agent when to call each beat (`session_begin`, `phase_enter`, `subagent_start`, `subagent_stop`, `artifact_update`, `validate`, `present_options`).

Add the contents of that file to your agent's system prompt or CLAUDE.md so it narrates its work through the cockpit.
