import { describe, it, expect, beforeEach } from "vitest";
import { Window } from "happy-dom";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";
import { initialState, startLaunch, setNavigatorOpen } from "../src/state.js";
import { toViewModel } from "../src/render.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const PUBLIC = path.join(here, "..", "public");

function boot() {
  const html = readFileSync(path.join(PUBLIC, "index.html"), "utf8");
  const js = readFileSync(path.join(PUBLIC, "client.js"), "utf8");
  const win = new Window({ url: "http://127.0.0.1:4399/" });
  win.document.write(html);
  const sent: any[] = [];
  // Stub the WebSocket so client.js can construct one; capture sent frames.
  (win as any).WebSocket = class {
    readyState = 1; onopen: any; onclose: any; onerror: any; onmessage: any;
    constructor() { /* no-op */ }
    send(s: string) { sent.push(JSON.parse(s)); }
    close() {}
  };
  // Execute the client module body in the window context.
  // Strip ES module import lines (happy-dom eval doesn't resolve bare specifiers).
  win.eval(js.replace(/^import .*$/gm, ""));
  return { win, sent };
}

describe("navigator client", () => {
  let env: ReturnType<typeof boot>;
  beforeEach(() => { env = boot(); });

  it("shows the home with the orient strip; the loop view stays out", () => {
    const view = toViewModel(initialState());
    (env.win as any).render(view);
    const doc = env.win.document;
    expect((doc.getElementById("home") as any).hidden).toBe(false);
    expect((doc.getElementById("loop") as any).hidden).toBe(true);
    // The orient strip is present; the launcher tiles live in the Navigator pop-up.
    expect(doc.getElementById("orient")).not.toBeNull();
  });

  it("shows the loop screen when the view is loop", () => {
    const view = toViewModel(startLaunch(initialState(), "build"));
    (env.win as any).render(view);
    expect((env.win.document.getElementById("home") as any).hidden).toBe(true);
    expect((env.win.document.getElementById("loop") as any).hidden).toBe(false);
  });

  it("renders the six workflow tiles into the Navigator pop-up", () => {
    (env.win as any).render(toViewModel(initialState()));
    const tiles = env.win.document.querySelectorAll("#nav-workflows [data-launch]");
    expect(tiles.length).toBe(6);
    expect(Array.from(tiles).map((t: any) => t.dataset.launch))
      .toEqual(["build", "review", "plan", "docs", "data", "coach"]);
  });

  it("launches a workflow and closes the pop-up when a tile is clicked", () => {
    (env.win as any).render(toViewModel(initialState()));
    const doc = env.win.document;
    const tile = doc.querySelector('#nav-workflows [data-launch="review"]') as any;
    tile.click();
    expect(env.sent).toContainEqual({ type: "launch", workflowId: "review" });
    expect((doc.getElementById("welcome") as any).hidden).toBe(true);
  });

  it("opens the pop-up when the view-model has navigatorOpen true", () => {
    (env.win as any).render(toViewModel(setNavigatorOpen(initialState(), true)));
    expect((env.win.document.getElementById("welcome") as any).hidden).toBe(false);
  });
});
