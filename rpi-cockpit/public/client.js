// rpi-cockpit/public/client.js
const ORDER = ["research", "plan", "implement", "review", "discover"];
const LABEL = { research: "Research", plan: "Plan", implement: "Implement", review: "Review", discover: "Discover" };
const ws = new WebSocket(`ws://${location.host}`);

ws.onmessage = (e) => {
  const msg = JSON.parse(e.data);
  if (msg.type === "state") { render(msg.state); }
};

function render(s) {
  const steps = document.getElementById("steps");
  if (steps) steps.innerHTML = ORDER.map((p, i) => {
    const status = s.phase === p ? "active" : s.phasesDone.includes(p) ? "done" : "pending";
    return `<div class="step ${status}"><div class="ring">${status === "done" ? "✓" : i + 1}</div>
      <div><div class="lbl">${i + 1} · ${LABEL[p]}</div></div></div>`;
  }).join("");

  const subs = document.getElementById("subagents");
  if (subs) subs.innerHTML = s.subagents.map((a) =>
    `<div class="sub-card"><div class="av">${initials(a.name)}</div>
      <div style="flex:1"><div class="nm">${escapeHtml(a.name)}</div><div class="meta">${escapeHtml(a.role ?? "")}</div></div>
      <span class="tagidle">${escapeHtml(a.status)}</span></div>`).join("") || "";

  const dec = document.getElementById("decision");
  if (dec) dec.innerHTML = s.pendingDecision ? decisionHtml(s.pendingDecision) : "";

  const gate = document.getElementById("gate");
  if (gate) gate.innerHTML = Object.entries(s.validations || {}).map(([check, status]) => {
    const cls = status === "ok" ? "ok" : status === "running" ? "run" : status === "fail" ? "fail" : "wait";
    const mark = status === "ok" ? "✓" : status === "running" ? "●" : status === "fail" ? "✕" : "○";
    return `<span class="check ${cls}">${mark} ${escapeHtml(check)}</span>`;
  }).join("");

  const stream = document.querySelector(".stream");
  if (stream) stream.innerHTML = s.log.slice(-12).map((l) =>
    `<div class="evt"><span class="ts">${new Date(l.t).toLocaleTimeString().slice(0, 5)}</span>
      <span><span class="k">${escapeHtml(l.kind)}</span> <span class="txt">${escapeHtml(l.detail)}</span></span></div>`).join("");
}

function decisionHtml(d) {
  const opts = d.options.map((o) =>
    `<div class="opt ${o.recommended ? "rec" : ""}">${o.recommended ? '<span class="badge">RECOMMENDED</span>' : ""}
      <h4>${escapeHtml(o.title)}</h4><p>${escapeHtml(o.detail ?? "")}</p></div>`).join("");
  const btns = d.options.map((o) =>
    `<button class="btn ${o.recommended ? "primary" : ""}" data-choice="${escapeHtml(o.id)}">Choose ${escapeHtml(o.title)}</button>`).join("");
  setTimeout(() => document.querySelectorAll("#decision [data-choice]").forEach((b) =>
    b.addEventListener("click", () => ws.send(JSON.stringify({ type: "decide", id: d.id, choiceId: b.dataset.choice })))), 0);
  return `<div class="decide"><div class="decide-head"><span class="t">${escapeHtml(d.prompt)}</span>
    <span class="s">present_options · awaiting your pick</span></div>
    <div class="decide-body"><div class="opts">${opts}</div><div class="btns">${btns}</div></div></div>`;
}

const initials = (n) => n.split(/\s+/).map((w) => w[0]).join("").slice(0, 2).toUpperCase();
const escapeHtml = (s) => String(s).replace(/[&<>"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c]));
