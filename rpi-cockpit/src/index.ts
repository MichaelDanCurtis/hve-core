// rpi-cockpit/src/index.ts
import { Bridge } from "./bridge.js";
import { startServer } from "./server.js";
import { buildMcpServer, connectStdio } from "./mcp.js";

const bridge = new Bridge();
const port = Number(process.env.RPI_COCKPIT_PORT ?? 4399);
await startServer(bridge, port);
process.stderr.write(`rpi-cockpit: http://127.0.0.1:${port}\n`);
await connectStdio(buildMcpServer(bridge));
