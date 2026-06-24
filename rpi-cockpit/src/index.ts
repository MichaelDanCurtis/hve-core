// rpi-cockpit/src/index.ts
import { Bridge } from "./bridge.js";
import { startServer } from "./server.js";
import { buildMcpServer, connectStdio } from "./mcp.js";

try {
  const bridge = new Bridge();
  const port = Number(process.env.RPI_COCKPIT_PORT ?? 4399);
  await startServer(bridge, port);
  process.stderr.write(`rpi-cockpit: http://127.0.0.1:${port}\n`);
  await connectStdio(buildMcpServer(bridge));
} catch (err) {
  const m = err instanceof Error ? err.message : String(err);
  process.stderr.write(`rpi-cockpit: failed to start (${m}). If the port is in use, set RPI_COCKPIT_PORT to a free port.\n`);
  process.exit(1);
}
