// rpi-cockpit/src/server.ts
import http from "node:http";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { WebSocketServer, type WebSocket } from "ws";
import type { Bridge } from "./bridge.js";
import type { SessionState } from "./state.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(here, "..", "public");
const TYPES: Record<string, string> = { ".html": "text/html", ".js": "text/javascript", ".css": "text/css" };

export async function startServer(bridge: Bridge, port = 4399) {
  const httpServer = http.createServer(async (req, res) => {
    const rel = (req.url === "/" || !req.url ? "/index.html" : req.url).split("?")[0];
    try {
      const file = await readFile(path.join(PUBLIC, rel));
      res.writeHead(200, { "content-type": TYPES[path.extname(rel)] ?? "application/octet-stream" });
      res.end(file);
    } catch {
      res.writeHead(404); res.end("not found");
    }
  });

  const wss = new WebSocketServer({ server: httpServer });
  const send = (ws: WebSocket, state: SessionState) => ws.send(JSON.stringify({ type: "state", state }));
  wss.on("connection", (ws) => {
    send(ws, bridge.state);
    ws.on("message", (data) => {
      const msg = JSON.parse(String(data));
      if (msg.type === "decide") bridge.resolveDecision(msg.id, msg.choiceId);
    });
  });
  const broadcast = (state: SessionState) => { for (const c of wss.clients) if (c.readyState === 1) send(c, state); };
  bridge.on("state", broadcast);

  await new Promise<void>((resolve) => httpServer.listen(port, resolve));
  const actual = (httpServer.address() as { port: number }).port;
  return {
    port: actual,
    close: () => new Promise<void>((resolve) => { bridge.off("state", broadcast); wss.close(); httpServer.close(() => resolve()); }),
  };
}
