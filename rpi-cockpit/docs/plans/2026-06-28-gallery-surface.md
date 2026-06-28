<!-- markdownlint-disable -->
# Gallery Surface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a new `gallery` loop view that renders a set of generic items (live URLs and inline HTML snapshots) as a scrollable grid of scaled live thumbnails with click-to-expand, driven by three new MCP tools, and feed the existing 65-agent contact sheet into it as one producer.

**Architecture:** A new `gallery` domain peer to review/backlog/interview/dataprofile. Three new beats (`gallery.open`, `gallery.add`, `gallery.clear`) and state fields (`galleryTitle`, `gallerySize`, `galleryItems`) feed a `gallery` view-model projection; three new MCP tools emit the beats; a new `#gallery-view` renders grouped scaled iframe thumbnails with an S/M/L toggle and a lightbox, with domain routing exactly like the existing views. A `tools/agent-gallery.mjs` producer renders the 65 agents via happy-dom and pushes them through `gallery_open`.

**Tech Stack:** TypeScript (ESM, strict), zod, Node `ws`, unbundled browser client (`public/client.js` + `public/index.html`), Vitest + happy-dom. Design spec: `docs/gallery-surface-design.md`.

## Global Constraints

* `GalleryItem = { id: string; label: string; group?: string; url?: string; html?: string; caption?: string }`.
* `galleryTitle: string | null`; `gallerySize: "s" | "m" | "l"` (default `"m"`); `galleryItems: GalleryItem[]`.
* The MCP tool count goes from 33 to 36 (three new tools; none removed). Update the assertion in `tests/mcp.test.ts`.
* `size` is a zod enum `["s","m","l"]` at the tool boundary; an out-of-enum value is rejected.
* `url` is validated at the tool boundary by `isGalleryUrl` (loopback http(s) OR any `https:`); a non-matching `url` is rejected. The client mirrors `isGalleryUrl` byte-for-byte (defense in depth) before assigning an iframe `src`.
* `gallery_open` fills a missing item `id` by position (`g0`, `g1`, ...); `gallery_add` requires an `id` and upserts by it IN PLACE (preserves order on update; appends a new id).
* The view-model `kind` is derived purely: `"url"` if `url` set, else `"html"` if `html` set, else `"empty"`. `src` carries the url, or the raw html string, or `null`.
* HTML snapshots reach the iframe via the `srcdoc` DOM property (`f.srcdoc = ...`), never via an HTML attribute string, so nested content is not re-escaped.
* TypeScript strict; no new `any`; ESM `.js` import specifiers in all `src/` imports.
* Every interpolation in `public/client.js` goes through the existing `esc()` helper.
* Keep the global `[hidden]{display:none!important}` rule and all existing iframe `sandbox` attributes untouched. Thumbnail iframes are `pointer-events:none` so a card click reaches the lightbox.
* Run `npx tsc --noEmit && npx vitest run` until green before each commit; `node --check public/client.js` must pass.
* House markdown for docs: asterisk bullets, no em-dashes, lint clean from the REPO ROOT.

---

### Task 1: Beats, state, and view-model

**Files:**
* Modify: `src/events.ts` (add the three beats to the `Beat` union)
* Modify: `src/state.ts` (domain union; `GalleryItem` type; the three fields; `initialState`; the three reducer arms; the three `summarize` arms)
* Modify: `src/render.ts` (domain union; `ViewModel.gallery`; the `toViewModel` projection)
* Test: `tests/state.test.ts`, `tests/render.test.ts`

**Interfaces:**
* Produces:
  * Beats `{ type: "gallery.open"; title: string; size?: "s"|"m"|"l"; items: GalleryItem[] }`, `{ type: "gallery.add"; item: GalleryItem }`, `{ type: "gallery.clear" }`.
  * `SessionState.galleryTitle`, `SessionState.gallerySize`, `SessionState.galleryItems`, `GalleryItem`.
  * `ViewModel.gallery: { title: string | null; size: "s"|"m"|"l"; items: { id: string; label: string; group: string | null; kind: "url"|"html"|"empty"; src: string | null; caption: string | null }[] }`.

* [ ] **Step 1: Write the failing tests**

Add to `tests/state.test.ts`:

```ts
describe("gallery", () => {
  it("gallery.open sets title/size/items, fills missing ids, and switches domain", () => {
    let s = applyBeat(initialState(), { type: "gallery.open", title: "My apps", size: "l", items: [
      { id: "", label: "Site", url: "https://example.com" },
      { id: "", label: "Snap", html: "<b>hi</b>" },
    ] }, 1);
    expect(s.domain).toBe("gallery");
    expect(s.view).toBe("loop");
    expect(s.galleryTitle).toBe("My apps");
    expect(s.gallerySize).toBe("l");
    expect(s.galleryItems.map((i) => i.id)).toEqual(["g0", "g1"]);
  });
  it("gallery.open defaults size to m", () => {
    const s = applyBeat(initialState(), { type: "gallery.open", title: "T", items: [] }, 1);
    expect(s.gallerySize).toBe("m");
  });
  it("gallery.add appends, and a same-id add updates in place (order preserved)", () => {
    let s = applyBeat(initialState(), { type: "gallery.open", title: "T", items: [{ id: "a", label: "A", url: "https://a.test" }] }, 1);
    s = applyBeat(s, { type: "gallery.add", item: { id: "b", label: "B", html: "<i>b</i>" } }, 2);
    s = applyBeat(s, { type: "gallery.add", item: { id: "a", label: "A2", url: "https://a2.test" } }, 3);
    expect(s.galleryItems.map((i) => i.id)).toEqual(["a", "b"]);
    expect(s.galleryItems[0]).toMatchObject({ id: "a", label: "A2", url: "https://a2.test" });
  });
  it("gallery.clear empties items but keeps title and domain", () => {
    let s = applyBeat(initialState(), { type: "gallery.open", title: "T", items: [{ id: "a", label: "A", url: "https://a.test" }] }, 1);
    s = applyBeat(s, { type: "gallery.clear" }, 2);
    expect(s.galleryItems).toEqual([]);
    expect(s.galleryTitle).toBe("T");
    expect(s.domain).toBe("gallery");
  });
});
```

Add to `tests/render.test.ts`:

```ts
it("projects the gallery with derived kind and src", () => {
  let s = applyBeat(initialState(), { type: "gallery.open", title: "G", size: "s", items: [
    { id: "u", label: "U", group: "live", url: "https://example.com" },
    { id: "h", label: "H", html: "<b>x</b>" },
    { id: "e", label: "E" },
  ] }, 1);
  const vm = toViewModel(s);
  expect(vm.domain).toBe("gallery");
  expect(vm.gallery.title).toBe("G");
  expect(vm.gallery.size).toBe("s");
  expect(vm.gallery.items).toEqual([
    { id: "u", label: "U", group: "live", kind: "url", src: "https://example.com", caption: null },
    { id: "h", label: "H", group: null, kind: "html", src: "<b>x</b>", caption: null },
    { id: "e", label: "E", group: null, kind: "empty", src: null, caption: null },
  ]);
  expect(toViewModel(initialState()).gallery.title).toBeNull();
  expect(toViewModel(initialState()).gallery.size).toBe("m");
});
```

* [ ] **Step 2: Run to verify they fail**

Run: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npx vitest run tests/state.test.ts tests/render.test.ts`
Expected: FAIL (beats/fields/projection not defined).

* [ ] **Step 3: Implement `src/events.ts`**

Add a shared `GalleryItem` zod object near `OptionItem` (after line 25):

```ts
export const GalleryItem = z.object({
  id: z.string().optional(),
  label: z.string(),
  group: z.string().optional(),
  url: z.string().optional(),
  html: z.string().optional(),
  caption: z.string().optional(),
});
export type GalleryItem = z.infer<typeof GalleryItem>;
```

Add to the `Beat` union (after the `codemap.touch` member at line 67, before the closing `]`):

```ts
  z.object({ type: z.literal("gallery.open"), title: z.string(), size: z.enum(["s", "m", "l"]).optional(), items: z.array(GalleryItem) }),
  z.object({ type: z.literal("gallery.add"), item: GalleryItem }),
  z.object({ type: z.literal("gallery.clear") }),
```

* [ ] **Step 4: Implement `src/state.ts`**

Add the `GalleryItem` interface near the other interfaces (e.g. after `DecisionEntry`):

```ts
export interface GalleryItem { id: string; label: string; group?: string; url?: string; html?: string; caption?: string; }
```

In the `domain` union (line 19) add `"gallery"`:

```ts
  domain: "rpi" | "review" | "interview" | "backlog" | "team" | "codemap" | "dataprofile" | "gallery" | null;
```

Add three fields to `SessionState` (near `profileColumns`):

```ts
  galleryTitle: string | null;
  gallerySize: "s" | "m" | "l";
  galleryItems: GalleryItem[];
```

In `initialState()`, add `galleryTitle: null, gallerySize: "m", galleryItems: []` to the returned object.

Add a small id-normaliser helper above `applyBeat` (so both open and add reuse it):

```ts
function normGalleryItem(it: { id?: string; label: string; group?: string; url?: string; html?: string; caption?: string }, idx: number): GalleryItem {
  return { id: it.id && it.id.length ? it.id : `g${idx}`, label: it.label, group: it.group, url: it.url, html: it.html, caption: it.caption };
}
```

Add the reducer arms (after the `column.add` arm):

```ts
    case "gallery.open":
      return { ...s, view: "loop", domain: "gallery", galleryTitle: beat.title, gallerySize: beat.size ?? "m", galleryItems: beat.items.map((it, i) => normGalleryItem(it, i)), log };
    case "gallery.add": {
      const item = normGalleryItem(beat.item, s.galleryItems.length);
      const exists = s.galleryItems.some((g) => g.id === item.id);
      return { ...s, view: "loop", domain: "gallery", galleryItems: exists ? s.galleryItems.map((g) => (g.id === item.id ? item : g)) : [...s.galleryItems, item], log };
    }
    case "gallery.clear":
      return { ...s, galleryItems: [], log };
```

In the `summarize(beat)` switch, add three arms (keep it exhaustive):

```ts
    case "gallery.open": return beat.title;
    case "gallery.add": return beat.item.label;
    case "gallery.clear": return "cleared";
```

* [ ] **Step 5: Implement `src/render.ts`**

In the `ViewModel` `domain` union add `"gallery"` (same as state). Add the `gallery` field to the `ViewModel` interface (near `dataProfile`):

```ts
  gallery: { title: string | null; size: "s" | "m" | "l"; items: { id: string; label: string; group: string | null; kind: "url" | "html" | "empty"; src: string | null; caption: string | null }[] };
```

In `toViewModel`, add to the returned object (near `dataProfile`):

```ts
    gallery: {
      title: s.galleryTitle,
      size: s.gallerySize,
      items: s.galleryItems.map((it) => ({
        id: it.id,
        label: it.label,
        group: it.group ?? null,
        kind: it.url ? "url" : it.html ? "html" : "empty",
        src: it.url ?? it.html ?? null,
        caption: it.caption ?? null,
      })),
    },
```

* [ ] **Step 6: Run the tests, then tsc + whole suite**

Run: `npx vitest run tests/state.test.ts tests/render.test.ts && npx tsc --noEmit && npx vitest run`
Expected: the new tests PASS; tsc clean; whole suite green. (If a test exact-matches the full `ViewModel`, add `gallery`; none is expected.)

* [ ] **Step 7: Commit**

```bash
git add rpi-cockpit/src/events.ts rpi-cockpit/src/state.ts rpi-cockpit/src/render.ts rpi-cockpit/tests/state.test.ts rpi-cockpit/tests/render.test.ts
git commit -m "feat(cockpit): gallery domain state, beats, and view-model"
```

---

### Task 2: URL predicate, MCP tools, and handlers

**Files:**
* Modify: `src/url.ts` (add `isGalleryUrl`)
* Modify: `src/handlers.ts` (add `gallery_open`, `gallery_add`, `gallery_clear`)
* Modify: `src/mcp.ts` (register the three tools)
* Test: `tests/url.test.ts` (if present; else assert via the tool test), `tests/mcp.test.ts` (round trip + tool count + rejections)

**Interfaces:**
* Consumes: the gallery beats from Task 1.
* Produces: `isGalleryUrl(u: string): boolean`; tools `gallery_open({ title, items, size? })`, `gallery_add({ item })`, `gallery_clear({})`.

* [ ] **Step 1: Write the failing test**

Add to `tests/mcp.test.ts` a round-trip test (build the client inline, matching the existing tests' style):

```ts
it("gallery tools drive the gallery state and reject bad input", async () => {
  const bridge = new Bridge();
  const server = buildMcpServer(bridge);
  const [clientT, serverT] = InMemoryTransport.createLinkedPair();
  await server.connect(serverT);
  const client = new Client({ name: "test", version: "0" });
  await client.connect(clientT);

  await client.callTool({ name: "gallery_open", arguments: { title: "Apps", size: "l", items: [
    { label: "Local", url: "http://localhost:3000/" },
    { label: "Snap", html: "<b>x</b>" },
  ] } });
  expect(bridge.state.domain).toBe("gallery");
  expect(bridge.state.galleryTitle).toBe("Apps");
  expect(bridge.state.gallerySize).toBe("l");
  expect(bridge.state.galleryItems.map((i) => i.id)).toEqual(["g0", "g1"]);

  await client.callTool({ name: "gallery_add", arguments: { item: { id: "x", label: "Ext", url: "https://example.com" } } });
  expect(bridge.state.galleryItems.at(-1)).toMatchObject({ id: "x", label: "Ext" });

  await client.callTool({ name: "gallery_clear", arguments: {} });
  expect(bridge.state.galleryItems).toEqual([]);

  const bad = await client.callTool({ name: "gallery_open", arguments: { title: "T", items: [{ label: "Bad", url: "http://evil.example.com" }] } });
  expect(bad.isError).toBe(true);
});
```

In the tool-count test, change `expect(tools).toHaveLength(33)` to `36` and add three `expect(names).toContain(...)` lines for `gallery_open`, `gallery_add`, `gallery_clear`.

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/mcp.test.ts`
Expected: FAIL (tools not registered; count is 33).

* [ ] **Step 3: Implement `src/url.ts`**

Add below `isLoopbackHttpUrl`:

```ts
// Gallery tiles may frame loopback dev servers (http or https) and external
// https sites. External http is rejected. The client mirrors this predicate
// before assigning an iframe src (defense in depth), so keep the two copies
// byte-for-byte equivalent (the copy lives in public/client.js).
export function isGalleryUrl(u: string): boolean {
  try {
    const url = new URL(u);
    if (url.protocol !== "http:" && url.protocol !== "https:") return false;
    if (isLoopbackHttpUrl(u)) return true;
    return url.protocol === "https:";
  } catch {
    return false;
  }
}
```

* [ ] **Step 4: Implement `src/handlers.ts`**

Add `isGalleryUrl` to the existing url import:

```ts
import { isLoopbackHttpUrl, isGalleryUrl } from "./url.js";
```

Add (next to the dataprofile handlers). Each gallery item with a `url` is validated; an invalid url throws (the MCP layer turns a thrown handler into an `isError` result, the same way `set_app_frame` rejects a non-loopback url):

```ts
  gallery_open: (b: Bridge, a: { title: string; size?: "s" | "m" | "l"; items: { id?: string; label: string; group?: string; url?: string; html?: string; caption?: string }[] }) => {
    for (const it of a.items) if (it.url && !isGalleryUrl(it.url)) throw new Error(`gallery url must be loopback http(s) or external https: ${it.url}`);
    b.emitBeat({ type: "gallery.open", title: a.title, size: a.size, items: a.items });
    return `gallery opened: ${a.title} (${a.items.length})`;
  },
  gallery_add: (b: Bridge, a: { item: { id?: string; label: string; group?: string; url?: string; html?: string; caption?: string } }) => {
    if (a.item.url && !isGalleryUrl(a.item.url)) throw new Error(`gallery url must be loopback http(s) or external https: ${a.item.url}`);
    b.emitBeat({ type: "gallery.add", item: a.item });
    return `gallery item: ${a.item.label}`;
  },
  gallery_clear: (b: Bridge) => {
    b.emitBeat({ type: "gallery.clear" });
    return "gallery cleared";
  },
```

Confirm `set_app_frame`'s handler throws on a bad url (it does); match that error style so the MCP layer reports `isError` consistently.

* [ ] **Step 5: Implement `src/mcp.ts`**

Add a reusable zod shape for a gallery item near the top of `buildMcpServer` (after `const text = ...` is fine, or inline):

```ts
  const galleryItemSchema = z.object({ id: z.string().optional(), label: z.string(), group: z.string().optional(), url: z.string().optional(), html: z.string().optional(), caption: z.string().optional() });
```

Register the three tools (after the dataprofile tools):

```ts
  server.registerTool(
    "gallery_open",
    { description: "Open the gallery view: a scrollable grid of scaled live thumbnails. Pass a title and an array of items; each item is EITHER a live `url` (a website or loopback dev server, framed live) OR an inline `html` snapshot, plus a `label`, optional `group` (section header), and optional `caption`. `url` must be a loopback http(s) URL or an external https URL. `size` is s/m/l (default m).", inputSchema: { title: z.string(), items: z.array(galleryItemSchema), size: z.enum(["s", "m", "l"]).optional() } },
    async (a) => text(handlers.gallery_open(bridge, a)),
  );

  server.registerTool(
    "gallery_add",
    { description: "Add or update one gallery tile by id (upsert). The item has the same shape as a gallery_open item (label, one of url/html, optional group/caption). Use this to stream tiles into an open gallery.", inputSchema: { item: galleryItemSchema } },
    async (a) => text(handlers.gallery_add(bridge, a)),
  );

  server.registerTool(
    "gallery_clear",
    { description: "Remove all tiles from the gallery (the view stays open with its title).", inputSchema: {} },
    async () => text(handlers.gallery_clear(bridge)),
  );
```

* [ ] **Step 6: Run the test, then tsc + whole suite**

Run: `npx vitest run tests/mcp.test.ts && npx tsc --noEmit && npx vitest run`
Expected: PASS; tsc clean; whole suite green (tool-count assertion now 36).

* [ ] **Step 7: Commit**

```bash
git add rpi-cockpit/src/url.ts rpi-cockpit/src/handlers.ts rpi-cockpit/src/mcp.ts rpi-cockpit/tests/mcp.test.ts
git commit -m "feat(cockpit): gallery_open/add/clear MCP tools with url validation"
```

---

### Task 3: The gallery client view, lightbox, and routing

**Files:**
* Modify: `public/index.html` (the `#gallery-view` markup, the `#gl-lightbox` overlay, and CSS)
* Modify: `public/client.js` (`isGalleryUrl` mirror; `renderGallery`; routing branch; hide `#gallery-view` in every other domain branch; lightbox + size-toggle wiring in the existing delegated click/keydown handlers)
* Test: `tests/gallery-client.test.ts` (new)

**Interfaces:**
* Consumes: `ViewModel.gallery` from Task 1.
* Produces: a `#gallery-view` shown when `v.domain === "gallery"`; a `#gl-grid` with one `.gl-card[data-gl]` per item and `.gl-group` section headers; a `#gl-lightbox` overlay toggled by a card click and closed by Escape.

* [ ] **Step 1: Write the failing test**

Create `tests/gallery-client.test.ts` (mirror `tests/dataprofile-client.test.ts`'s `boot()` harness):

```ts
import { describe, it, expect, beforeEach } from "vitest";
import { Window } from "happy-dom";
import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { initialState, applyBeat } from "../src/state.js";
import { toViewModel } from "../src/render.js";

const PUBLIC = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "public");
function boot() {
  const html = readFileSync(path.join(PUBLIC, "index.html"), "utf8");
  const js = readFileSync(path.join(PUBLIC, "client.js"), "utf8");
  const win = new Window({ url: "http://127.0.0.1:4399/" });
  win.document.write(html);
  (win as any).WebSocket = class { readyState = 1; send() {} close() {} };
  win.eval(js.replace(/^import .*$/gm, ""));
  return win;
}
function galleryVm() {
  const s = applyBeat(initialState(), { type: "gallery.open", title: "My apps", size: "m", items: [
    { id: "u", label: "Local", group: "live", url: "http://localhost:3000/" },
    { id: "h", label: "Snap", group: "live", html: "<b>hi</b>" },
  ] }, 1);
  return toViewModel(s);
}

describe("gallery client", () => {
  let win: ReturnType<typeof boot>;
  beforeEach(() => { win = boot(); });

  it("shows the gallery view and hides the others on the gallery domain", () => {
    (win as any).render(galleryVm());
    expect((win.document.getElementById("gallery-view") as any).hidden).toBe(false);
    expect((win.document.getElementById("rpi-view") as any).hidden).toBe(true);
    expect((win.document.getElementById("dataprofile-view") as any).hidden).toBe(true);
  });

  it("renders one card per item, a group header, and the right iframe sandbox/src", () => {
    (win as any).render(galleryVm());
    const cards = win.document.querySelectorAll("#gl-grid .gl-card");
    expect(cards.length).toBe(2);
    expect(win.document.querySelector("#gl-grid .gl-group")?.textContent).toBe("live");
    const urlFrame = win.document.getElementById("gl-thumb-0") as any;
    expect(urlFrame.getAttribute("sandbox")).toBe("allow-scripts allow-same-origin allow-forms");
    expect(urlFrame.getAttribute("src")).toBe("http://localhost:3000/");
    const htmlFrame = win.document.getElementById("gl-thumb-1") as any;
    expect(htmlFrame.getAttribute("sandbox")).toBe("");
    expect(htmlFrame.srcdoc).toBe("<b>hi</b>");
  });

  it("opens the lightbox on a card click and closes on Escape", () => {
    (win as any).render(galleryVm());
    (win.document.querySelector("#gl-grid .gl-card") as any).dispatchEvent(new win.Event("click", { bubbles: true }));
    expect((win.document.getElementById("gl-lightbox") as any).hidden).toBe(false);
    win.document.dispatchEvent(new win.Event("keydown", { bubbles: true }));
    // (the keydown handler keys off e.key === "Escape"; see implementation note)
  });
});
```

Note: happy-dom's synthetic `Event` has no `key`; if asserting Escape is awkward in the harness, assert the lightbox opens (the first two assertions) and that `closeLightbox()` hides it by calling it directly via `win.eval("closeLightbox()")`. Keep the test deterministic; do not rely on `KeyboardEvent.key` if the harness does not support it.

* [ ] **Step 2: Run to verify it fails**

Run: `npx vitest run tests/gallery-client.test.ts`
Expected: FAIL (no `#gallery-view`).

* [ ] **Step 3: Markup + CSS in `public/index.html`**

Add the view as a sibling of `#dataprofile-view` (after it, still inside `#loop`):

```html
    <section id="gallery-view" hidden>
      <div class="rev-head">
        <span class="board-target" id="gl-title">Gallery</span>
        <span class="board-count" id="gl-count"></span>
        <span class="gl-sizes" role="group" aria-label="Thumbnail size">
          <button type="button" class="gl-size" data-gsize="s">S</button>
          <button type="button" class="gl-size" data-gsize="m">M</button>
          <button type="button" class="gl-size" data-gsize="l">L</button>
        </span>
      </div>
      <div id="gl-grid"></div>
    </section>
```

Add the lightbox overlay just before `</body>` (a top-level fixed element, OUTSIDE `#loop` so it overlays the whole cockpit):

```html
  <div id="gl-lightbox" hidden>
    <div class="gl-lb-head">
      <span id="gl-lb-label"></span>
      <a id="gl-lb-open" href="#" target="_blank" rel="noopener" hidden>open in tab ↗</a>
      <button type="button" id="gl-lb-close" aria-label="Close">✕</button>
    </div>
    <div class="gl-lb-body"><iframe id="gl-lb-frame" title="Gallery item"></iframe></div>
  </div>
```

Add the CSS (next to the `.board-*` / `.dp-*` rules). The thumbnail iframe is a fixed 1200x780 logical viewport scaled by the size class; the wrapper clips it to the scaled height:

```css
  #gallery-view { flex: 1 1 0; min-height: 0; display: flex; flex-direction: column; overflow: hidden; }
  .gl-sizes { margin-left: auto; display: inline-flex; gap: 2px; }
  .gl-size { font: inherit; font-size: 11px; padding: 2px 9px; background: var(--bar, #323233); color: var(--text-2, #9D9D9D); border: 1px solid var(--stroke, #3C3C3C); cursor: pointer; }
  .gl-size.active { background: var(--brand, #0E639C); color: #fff; border-color: transparent; }
  #gl-grid { flex: 1; overflow: auto; padding: 14px 18px; display: grid; gap: 16px; align-content: start; justify-content: start; }
  #gl-grid.gsize-s { grid-template-columns: repeat(auto-fill, 300px); }
  #gl-grid.gsize-m { grid-template-columns: repeat(auto-fill, 460px); }
  #gl-grid.gsize-l { grid-template-columns: repeat(auto-fill, 640px); }
  .gl-group { grid-column: 1 / -1; font-size: 11px; text-transform: uppercase; letter-spacing: .06em; color: var(--text-3, #6E6E6E); font-weight: 600; margin-top: 6px; padding-bottom: 4px; border-bottom: 1px solid var(--stroke, #3C3C3C); }
  .gl-card { margin: 0; border: 1px solid var(--stroke, #3C3C3C); border-radius: 8px; overflow: hidden; background: #111; cursor: pointer; }
  .gl-cap { display: flex; align-items: baseline; gap: 8px; padding: 7px 10px; background: var(--bar, #323233); font-size: 12.5px; }
  .gl-cap .gl-label { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .gl-cap .gl-caption { color: var(--text-3, #6E6E6E); font-size: 11px; white-space: nowrap; }
  .gl-cap .gl-open { margin-left: auto; color: var(--accent-blue, #4FC1FF); text-decoration: none; font-size: 11px; }
  .gl-thumb { overflow: hidden; background: #1E1E1E; }
  .gl-thumb iframe { border: 0; transform-origin: top left; pointer-events: none; }
  .gl-thumb .meta { padding: 18px; }
  #gl-grid.gsize-s .gl-thumb { height: 195px; }
  #gl-grid.gsize-s .gl-thumb iframe { width: 1200px; height: 780px; transform: scale(.25); }
  #gl-grid.gsize-m .gl-thumb { height: 299px; }
  #gl-grid.gsize-m .gl-thumb iframe { width: 1200px; height: 780px; transform: scale(.383); }
  #gl-grid.gsize-l .gl-thumb { height: 416px; }
  #gl-grid.gsize-l .gl-thumb iframe { width: 1200px; height: 780px; transform: scale(.533); }
  #gl-lightbox { position: fixed; inset: 0; z-index: 50; background: rgba(0,0,0,.72); display: flex; flex-direction: column; padding: 24px; }
  .gl-lb-head { display: flex; align-items: center; gap: 14px; color: #eee; padding: 6px 4px; font-size: 13px; }
  #gl-lb-label { font-weight: 600; }
  #gl-lb-open { margin-left: auto; color: var(--accent-blue, #4FC1FF); }
  #gl-lb-close { background: transparent; border: 0; color: #ccc; font-size: 18px; cursor: pointer; }
  .gl-lb-body { flex: 1; min-height: 0; background: #1e1e1e; border-radius: 8px; overflow: hidden; }
  #gl-lb-frame { width: 100%; height: 100%; border: 0; }
```

* [ ] **Step 4: Implement `public/client.js`**

Near the top (next to the existing `isLoopbackHttpUrl` mirror, if present; otherwise after `esc`), add the byte-for-byte mirror of `isGalleryUrl`:

```js
function isLoopbackHttpUrl(u) {
  try {
    const url = new URL(u);
    if (url.protocol !== "http:" && url.protocol !== "https:") return false;
    const h = url.hostname.toLowerCase();
    return h === "localhost" || h === "127.0.0.1" || h === "[::1]" || h === "::1";
  } catch { return false; }
}
function isGalleryUrl(u) {
  try {
    const url = new URL(u);
    if (url.protocol !== "http:" && url.protocol !== "https:") return false;
    if (isLoopbackHttpUrl(u)) return true;
    return url.protocol === "https:";
  } catch { return false; }
}
```

(If `isLoopbackHttpUrl` already exists in client.js for the app frame, do NOT duplicate it; add only `isGalleryUrl`.)

Add module-level gallery state near the other module vars (e.g. near `let cmSig`):

```js
let glItems = [];
let glSizeOverride = null;
```

In `render(v)`, after `const dataprofileView = document.getElementById("dataprofile-view");` add:

```js
  const galleryView = document.getElementById("gallery-view");
```

In EACH existing domain branch (`codemap`, `team`, `backlog`, `dataprofile`, `interview`) and the review/default tail, add alongside the other hide lines:

```js
      if (galleryView) galleryView.hidden = true;
```

Add the new `gallery` branch (place it next to the `dataprofile` branch):

```js
    if (v.domain === "gallery") {
      rpiView.hidden = true; findingsView.hidden = true;
      if (interviewView) interviewView.hidden = true;
      if (backlogView) backlogView.hidden = true;
      if (teamView) teamView.hidden = true;
      if (codemapView) codemapView.hidden = true;
      if (dataprofileView) dataprofileView.hidden = true;
      if (galleryView) galleryView.hidden = false;
      renderGallery(v);
      return;
    }
```

Add `renderGallery` and `glCard` (next to `renderBoard`):

```js
function glCard(it, i) {
  const sandbox = it.kind === "url" ? `sandbox="allow-scripts allow-same-origin allow-forms"` : `sandbox=""`;
  const open = it.kind === "url" && it.src ? `<a class="gl-open" href="${esc(it.src)}" target="_blank" rel="noopener" data-noexpand>open ↗</a>` : "";
  const cap = it.caption ? `<span class="gl-caption">${esc(it.caption)}</span>` : "";
  const thumb = it.kind === "empty"
    ? `<div class="meta">${esc(it.label)}</div>`
    : `<iframe id="gl-thumb-${i}" ${sandbox} title="${esc(it.label)}" tabindex="-1"></iframe>`;
  return `<figure class="gl-card" data-gl="${i}"><figcaption class="gl-cap"><span class="gl-label">${esc(it.label)}</span>${cap}${open}</figcaption><div class="gl-thumb">${thumb}</div></figure>`;
}

function renderGallery(v) {
  const g = v.gallery || { title: null, size: "m", items: [] };
  glItems = g.items;
  setText("gl-title", g.title || "Gallery");
  setText("gl-count", g.items.length ? `${g.items.length} items` : "");
  const grid = document.getElementById("gl-grid");
  if (!grid) return;
  const size = glSizeOverride || g.size || "m";
  grid.className = `gsize-${size}`;
  document.querySelectorAll(".gl-size").forEach((b) => b.classList.toggle("active", b.dataset.gsize === size));
  const order = [];
  const byGroup = new Map();
  g.items.forEach((it, i) => {
    const key = it.group || "";
    if (!byGroup.has(key)) { byGroup.set(key, []); order.push(key); }
    byGroup.get(key).push({ it, i });
  });
  grid.innerHTML = order.map((key) => {
    const head = key ? `<div class="gl-group">${esc(key)}</div>` : "";
    return head + byGroup.get(key).map(({ it, i }) => glCard(it, i)).join("");
  }).join("") || `<div class="meta" style="padding:14px">No items yet.</div>`;
  // Assign each thumbnail source as a DOM property (no HTML-attribute escaping).
  g.items.forEach((it, i) => {
    const f = document.getElementById(`gl-thumb-${i}`);
    if (!f) return;
    if (it.kind === "url" && it.src && isGalleryUrl(it.src)) f.setAttribute("src", it.src);
    else if (it.kind === "html") f.srcdoc = it.src || "";
  });
}

function openLightbox(i) {
  const it = glItems[i];
  if (!it) return;
  const lb = document.getElementById("gl-lightbox");
  const frame = document.getElementById("gl-lb-frame");
  const openLink = document.getElementById("gl-lb-open");
  setText("gl-lb-label", it.label);
  if (it.kind === "url" && it.src && isGalleryUrl(it.src)) {
    frame.removeAttribute("srcdoc"); frame.setAttribute("src", it.src);
    if (openLink) { openLink.href = it.src; openLink.hidden = false; }
  } else if (it.kind === "html") {
    frame.removeAttribute("src"); frame.srcdoc = it.src || "";
    if (openLink) openLink.hidden = true;
  } else {
    frame.removeAttribute("src"); frame.srcdoc = `<body style="margin:0;background:#1e1e1e"></body>`;
    if (openLink) openLink.hidden = true;
  }
  if (lb) lb.hidden = false;
}

function closeLightbox() {
  const lb = document.getElementById("gl-lightbox");
  const frame = document.getElementById("gl-lb-frame");
  if (frame) { frame.removeAttribute("src"); frame.removeAttribute("srcdoc"); }
  if (lb) lb.hidden = true;
}
```

In the existing delegated click handler (`document.addEventListener("click", (e) => { ... }`), add near the top of the handler body:

```js
  const gsize = e.target.closest(".gl-size[data-gsize]");
  if (gsize) {
    glSizeOverride = gsize.dataset.gsize;
    const grid = document.getElementById("gl-grid");
    if (grid) grid.className = `gsize-${glSizeOverride}`;
    document.querySelectorAll(".gl-size").forEach((b) => b.classList.toggle("active", b.dataset.gsize === glSizeOverride));
    return;
  }
  if (e.target.closest("#gl-lb-close")) { closeLightbox(); return; }
  if (e.target.id === "gl-lightbox") { closeLightbox(); return; } // backdrop
  if (e.target.closest("[data-noexpand]")) return; // let open-in-tab work
  const glCardEl = e.target.closest(".gl-card[data-gl]");
  if (glCardEl) { openLightbox(+glCardEl.dataset.gl); return; }
```

In the existing keydown handler (`document.addEventListener("keydown", (e) => { ... }`), add:

```js
  if (e.key === "Escape") {
    const lb = document.getElementById("gl-lightbox");
    if (lb && !lb.hidden) { closeLightbox(); return; }
  }
```

* [ ] **Step 5: Run the test, then tsc + node check + whole suite**

Run: `npx vitest run tests/gallery-client.test.ts && npx tsc --noEmit && node --check public/client.js && npx vitest run`
Expected: ALL green.

* [ ] **Step 6: Commit**

```bash
git add rpi-cockpit/public/index.html rpi-cockpit/public/client.js rpi-cockpit/tests/gallery-client.test.ts
git commit -m "feat(cockpit): gallery view with scaled thumbnails, size toggle, and lightbox"
```

---

### Task 4: The agent-gallery producer

**Files:**
* Create: `tools/agent-gallery.mjs` (tracked; supersedes the untracked `.gen-gallery.mjs`)
* Delete: `.gen-gallery.mjs`, `public/gallery.html` (scratch artifacts; the surface replaces them)

**Interfaces:**
* Consumes: `buildMcpServer`/`Bridge`/`startServer`/`handlers` from `dist/`, the same happy-dom render-capture from the scratch generator, and `gallery_open`.
* Produces: a standalone producer that serves a live cockpit showing the 65 agents as `html` gallery items.

* [ ] **Step 1: Write `tools/agent-gallery.mjs`**

Port the render-capture logic from `.gen-gallery.mjs` (the `capture(beats, mutate)` happy-dom function, the `inlineSrcdoc` data-URL conversion, the dark-pane wrapping, the app-frame mock injection, and the 65-agent `CATS` data) UNCHANGED, but replace the static-file output with: build one `html` gallery item per agent (`{ id: "a"+n, label: "#"+n+" "+name, group: cat, html: cockpitDocFor(innerHTML) }`), stand up a producer, and call `gallery_open`.

```js
import { Bridge } from "../dist/bridge.js";
import { startServer } from "../dist/server.js";
import { handlers } from "../dist/handlers.js";
import { liveStateDir } from "../dist/paths.js";
// ...plus the capture/inlineSrcdoc/CATS code ported from the old .gen-gallery.mjs...

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..", "..");
const items = [];
for (const { cat, agents } of CATS) {
  for (const [n, name, built] of agents) {
    let inner = capture(built.beats, built.mutate);
    inner = inlineSrcdoc(inner);
    if (built.appMock) inner = inner.replace(/(<iframe\b[^>]*\bid="af-iframe"[^>]*?)\ssrc="[^"]*"/, `$1 src="${DASH_DATAURL}"`);
    const doc = `<!doctype html><html><head><meta charset=utf8><style>${CSS}\nhtml,body{height:100%}body{overflow:hidden;background:#1A1A1A}</style></head><body>${inner}</body></html>`;
    items.push({ id: `a${n}`, label: `#${n} ${name}`, group: cat, html: doc });
  }
}

const bridge = new Bridge();
const port = Number(process.env.PORT) || 4505;
const stateDir = process.env.RPI_COCKPIT_STATE_DIR ?? liveStateDir(path.join(root, "rpi-cockpit"));
const srv = await startServer(bridge, port, { stateDir, writeStateSnapshot: true });
handlers.gallery_open(bridge, { title: "HVE Core agents", size: "m", items });
process.stderr.write(`agent gallery: ${srv.url}\n`);
setInterval(() => {}, 1 << 30);
```

The producer serves the cockpit itself, so opening `srv.url` shows the gallery; because it also writes `state.json`, a separately running `rpi-cockpit live` consumer pane shows it too.

* [ ] **Step 2: Delete the scratch artifacts**

```bash
rm -f rpi-cockpit/.gen-gallery.mjs rpi-cockpit/public/gallery.html
```

* [ ] **Step 3: Build and smoke-run**

Run: `cd "/Volumes/Main External/Development/hve-core/rpi-cockpit" && npm run build && node tools/agent-gallery.mjs`
Expected: prints `agent gallery: http://...`; the process stays up. Open the URL (or the consumer pane) and confirm the 65 agents render grouped by category. Stop it after the visual check (Ctrl-C, or leave running for Task-level verification).

* [ ] **Step 4: Commit**

```bash
git add rpi-cockpit/tools/agent-gallery.mjs
git rm --cached rpi-cockpit/.gen-gallery.mjs rpi-cockpit/public/gallery.html 2>/dev/null || true
git commit -m "feat(cockpit): agent-gallery producer feeds the gallery surface"
```

(The scratch files are untracked, so `git rm --cached` is a no-op guarded with `|| true`; the `rm -f` in Step 2 removes them from disk.)

---

### Task 5: Agent contract for the gallery

**Files:**
* Modify: `rpi-cockpit/agents/cockpit-instructions.md`
* Modify: `CLAUDE.md` (the "Cockpit instrumentation" section, repo root)

**Interfaces:**
* Consumes: nothing in code; the narration contract every agent reads.

* [ ] **Step 1: Edit `agents/cockpit-instructions.md`**

Add a new section (after the backlog or data-science section):

```markdown
## Gallery (show several things at once)

* `gallery_open(title, items, size?)` opens a scrollable grid of scaled live thumbnails. Each item is one of a live `url` (a website or a loopback dev server, framed live) OR an inline `html` snapshot, plus a `label`, optional `group` (a section header), and optional `caption`. `url` must be a loopback http(s) URL or an external https URL. `size` is s/m/l (default m).
* `gallery_add(item)` adds or updates one tile by `id`; `gallery_clear()` empties the board.
* Use it to compare several running apps or sites side by side (`url` items), or several rendered states (`html` items). Clicking a tile expands it; external sites that block framing show blank, so an open-in-tab link is always offered.
```

* [ ] **Step 2: Edit the repo `CLAUDE.md`**

In the "Cockpit instrumentation" section, add a Gallery subsection mirroring the others (one paragraph: the three tools and the one-of-url-or-html rule).

* [ ] **Step 3: Lint from the repo root**

Run: `cd "/Volumes/Main External/Development/hve-core" && npx markdownlint-cli2 "rpi-cockpit/agents/cockpit-instructions.md" "CLAUDE.md"`
Expected: `Summary: 0 error(s)`. (Keep asterisk bullets, no em-dashes; split a long line if a length rule trips. Note: if `CLAUDE.md` is excluded by the lint config globs, lint only the contract file.)

* [ ] **Step 4: Commit**

```bash
git add rpi-cockpit/agents/cockpit-instructions.md CLAUDE.md
git commit -m "docs(cockpit): gallery narration contract"
```

---

## Final verification (after Task 5)

* [ ] `cd rpi-cockpit && npx tsc --noEmit && npx vitest run` fully green; `node --check public/client.js` OK.
* [ ] `npm run build`, then verify live in a RESTARTED consumer pane (a render.ts/state change requires a consumer restart, not just a browser reload):
  * A `url` gallery: drive `gallery_open("My apps", [{label, url: "http://localhost:PORT/"}, {label, url:"https://example.com"}])`; confirm the dev-server tile frames live and the external tile either frames or shows blank with an open-in-tab link.
  * The agent gallery: run `node tools/agent-gallery.mjs` and confirm the 65 agents render grouped by category.
  * The S/M/L toggle rescales tiles; clicking a tile opens the lightbox full-size and scrollable; Escape/backdrop/✕ closes it.
* [ ] Push to `fork` and open a PR.

## Self-Review

**Spec coverage:** the `gallery` domain + state (Task 1) covered; the three beats + tools with url/size validation (Tasks 1, 2) covered; the view-model `kind`/`src` derivation (Task 1) covered; the `#gallery-view` grid + S/M/L toggle + lightbox + open-in-tab + sandbox + blocked-frame honesty (Task 3) covered; the `tools/agent-gallery.mjs` producer (Task 4) covered; the agent contract (Task 5) covered. Deferred items (persistence, screenshotting, auto-refresh, drag-reorder, cross-origin measurement) correctly absent.

**Placeholder scan:** every code step shows complete code. The one ported block (Task 4's `capture`/`inlineSrcdoc`/`CATS`) references the existing `.gen-gallery.mjs` rather than re-pasting ~200 lines verbatim; that file exists in the working tree at plan time and the porting transform (swap the static-file write for `gallery_open`) is given in full. No TBD/TODO.

**Type consistency:** `GalleryItem` fields are identical across the zod object (Task 1 events.ts), the state interface (Task 1 state.ts), the tool inputSchema (Task 2 mcp.ts), and the handler arg types (Task 2 handlers.ts). The view-model widens to the projected shape with `kind`/`src`/`group: string | null`/`caption: string | null` consistently used by the client (Task 3) and asserted in the render test (Task 1) and client test (Task 3). `isGalleryUrl` is defined once in `src/url.ts` (Task 2) and mirrored byte-for-byte in `public/client.js` (Task 3). The names `gallery_open`/`gallery_add`/`gallery_clear`/`gallery.open`/`gallery.add`/`gallery.clear`/`renderGallery`/`#gallery-view`/`gl-grid`/`gl-thumb-{i}`/`gl-lightbox` are consistent across all tasks.
