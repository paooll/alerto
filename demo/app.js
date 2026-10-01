/* Alerto web demo — simulated market data, mirrors the Flutter app UX. */
"use strict";

// ---------- Simulated market engine (no external API calls) ----------

const INSTRUMENTS = [
  { symbol: "EUR/USD", name: "Euro / US Dollar", cls: "Forex", prec: 5, price: 1.0864, pip: 0.0001 },
  { symbol: "GBP/USD", name: "British Pound / US Dollar", cls: "Forex", prec: 5, price: 1.2695 },
  { symbol: "USD/JPY", name: "US Dollar / Japanese Yen", cls: "Forex", prec: 3, price: 151.42 },
  { symbol: "USD/CHF", name: "US Dollar / Swiss Franc", cls: "Forex", prec: 5, price: 0.9012 },
  { symbol: "AUD/USD", name: "Australian Dollar / US Dollar", cls: "Forex", prec: 5, price: 0.6571 },
  { symbol: "USD/CAD", name: "US Dollar / Canadian Dollar", cls: "Forex", prec: 5, price: 1.3584 },
  { symbol: "NZD/USD", name: "New Zealand Dollar / US Dollar", cls: "Forex", prec: 5, price: 0.6019 },
  { symbol: "EUR/GBP", name: "Euro / British Pound", cls: "Forex", prec: 5, price: 0.8556 },
  { symbol: "XAU/USD", name: "Gold / US Dollar", cls: "Metal", prec: 2, price: 2651.4 },
  { symbol: "XAG/USD", name: "Silver / US Dollar", cls: "Metal", prec: 3, price: 31.204 },
  { symbol: "SPX", name: "S&P 500", cls: "Index", prec: 2, price: 5702.55 },
  { symbol: "IXIC", name: "Nasdaq Composite", cls: "Index", prec: 2, price: 18119.6 },
  { symbol: "DJI", name: "Dow Jones 30", cls: "Index", prec: 2, price: 42313.0 },
];

const state = {
  instruments: INSTRUMENTS.map((i) => ({
    ...i,
    bid: i.price - (i.pip || 0.01) * 1.2,
    ask: i.price + (i.pip || 0.01) * 1.2,
    prevClose: i.price * (1 + (Math.random() - 0.5) * 0.01),
    updated: Date.now(),
    history: makeHistory(i.price),
  })),
  alerts: [],
  history: [],
  selected: null,
  logic: "all",
  mode: "once",
  cooldown: 30,
  email: "",
};

function makeHistory(base) {
  const pts = [];
  let p = base * (1 - 0.004);
  for (let i = 0; i < 96; i++) {
    p += (Math.random() - 0.48) * base * 0.0009;
    pts.push(p);
  }
  pts[pts.length - 1] = base;
  return pts;
}

// Random-walk tick every 2s
setInterval(() => {
  for (const inst of state.instruments) {
    const drift = (Math.random() - 0.5) * inst.price * 0.0006;
    inst.price = +(inst.price + drift).toFixed(inst.prec + 1);
    inst.bid = +(inst.price - (inst.pip || 0.01) * 1.2).toFixed(inst.prec + 1);
    inst.ask = +(inst.price + (inst.pip || 0.01) * 1.2).toFixed(inst.prec + 1);
    inst.updated = Date.now();
    inst.history.push(inst.price);
    if (inst.history.length > 96) inst.history.shift();
  }
  renderDynamic();
  evaluateAlerts();
}, 2000);

// ---------- Helpers ----------

const $ = (sel) => document.querySelector(sel);
const fmt = (v, prec) => v.toLocaleString("en-US", { minimumFractionDigits: prec, maximumFractionDigits: prec });
const changePct = (inst) => ((inst.price - inst.prevClose) / inst.prevClose) * 100;

function showScreen(id) {
  document.querySelectorAll(".screen").forEach((s) => s.classList.remove("active"));
  $(`#screen-${id}`).classList.add("active");
  $("#bottom-nav").style.display = ["dashboard", "alerts", "history", "settings"].includes(id) ? "flex" : "none";
  document.querySelectorAll(".bottom-nav button").forEach((b) =>
    b.classList.toggle("active", b.dataset.tab === id)
  );
}

document.addEventListener("click", (e) => {
  const nav = e.target.closest("[data-nav]");
  if (nav) showScreen(nav.dataset.nav);
  const tab = e.target.closest("[data-tab]");
  if (tab) showScreen(tab.dataset.tab);
});

// ---------- Auth ----------

let isRegister = false;
$("#auth-toggle").addEventListener("click", () => {
  isRegister = !isRegister;
  $("#auth-submit").textContent = isRegister ? "Create account" : "Sign in";
  $("#auth-toggle").textContent = isRegister ? "Already have an account? Sign in" : "New here? Create an account";
});

$("#auth-form").addEventListener("submit", (e) => {
  e.preventDefault();
  const email = $("#auth-email").value.trim();
  const pass = $("#auth-pass").value;
  const err = $("#auth-error");
  if (!email.includes("@")) return showError("Enter a valid email address.");
  if (pass.length < 6) return showError("Password must be at least 6 characters.");
  err.classList.add("hidden");
  state.email = email;
  $("#settings-email").textContent = email;
  showScreen("dashboard");
  renderMarkets();
});

function showError(msg) {
  const err = $("#auth-error");
  err.textContent = msg;
  err.classList.remove("hidden");
}

$("#signout").addEventListener("click", () => {
  state.email = "";
  showScreen("auth");
});

// ---------- Dashboard / markets ----------

function renderMarkets() {
  const list = $("#market-list");
  const counts = {};
  state.alerts.filter((a) => a.enabled && !isExpired(a)).forEach((a) => {
    counts[a.symbol] = (counts[a.symbol] || 0) + 1;
  });
  list.innerHTML = state.instruments
    .map((inst) => {
      const ch = changePct(inst);
      const up = ch >= 0;
      return `<div class="card tile-flex" data-inst="${inst.symbol}">
        <div>
          <div class="tile-top">
            <span class="tile-symbol">${inst.symbol}</span>
            ${counts[inst.symbol] ? `<span class="badge-count">${counts[inst.symbol]}</span>` : ""}
          </div>
          <div class="tile-name">${inst.name}</div>
        </div>
        <div class="tile-right">
          <div class="tile-price">${fmt(inst.price, inst.prec)}</div>
          <div class="tile-change" style="color:${up ? "var(--green)" : "var(--red)"}">${up ? "+" : ""}${ch.toFixed(2)}%</div>
        </div>
      </div>`;
    })
    .join("");
  list.querySelectorAll("[data-inst]").forEach((el) =>
    el.addEventListener("click", () => openDetail(el.dataset.inst))
  );
}

// ---------- Search ----------

$("#search-input").addEventListener("input", () => renderSearch());
function renderSearch() {
  const q = $("#search-input").value.trim().toLowerCase();
  const results = state.instruments.filter(
    (i) => !q || i.symbol.toLowerCase().includes(q) || i.name.toLowerCase().includes(q)
  );
  $("#search-list").innerHTML = results.length
    ? results
        .map(
          (i) => `<div class="card" data-inst="${i.symbol}">
            <div class="tile-top"><span class="tile-symbol">${i.symbol}</span><span class="chip">${i.cls}</span></div>
            <div class="tile-name">${i.name}</div>
          </div>`
        )
        .join("")
    : `<p class="empty">No instruments match your search.</p>`;
  $("#search-list").querySelectorAll("[data-inst]").forEach((el) =>
    el.addEventListener("click", () => openDetail(el.dataset.inst))
  );
}

// ---------- Detail ----------

let chartInterval = "1h";
const INTERVALS = { "15min": "15M", "1h": "1H", "4h": "4H", "1day": "1D" };

function openDetail(symbol) {
  state.selected = symbol;
  $("#detail-symbol").textContent = symbol;
  $("#chart-intervals").innerHTML = Object.entries(INTERVALS)
    .map(([k, v]) => `<button data-int="${k}" class="${k === chartInterval ? "active" : ""}">${v}</button>`)
    .join("");
  $("#chart-intervals").querySelectorAll("button").forEach((b) =>
    b.addEventListener("click", () => {
      chartInterval = b.dataset.int;
      $("#chart-intervals").querySelectorAll("button").forEach((x) => x.classList.toggle("active", x === b));
      drawChart();
    })
  );
  $("#fab-create").onclick = () => openAlertEdit();
  showScreen("detail");
  renderDetail();
  drawChart();
}

function renderDetail() {
  const inst = state.instruments.find((i) => i.symbol === state.selected);
  if (!inst) return;
  $("#detail-name").textContent = inst.name;
  $("#detail-price").textContent = fmt(inst.price, inst.prec);
  $("#detail-time").textContent = new Date(inst.updated).toLocaleTimeString();
  const ch = changePct(inst);
  const up = ch >= 0;
  const el = $("#detail-change");
  el.textContent = `${up ? "↑" : "↓"} ${up ? "+" : ""}${ch.toFixed(2)}% vs prev close`;
  el.style.color = up ? "var(--green)" : "var(--red)";
  $("#detail-bid").textContent = fmt(inst.bid, inst.prec);
  $("#detail-ask").textContent = fmt(inst.ask, inst.prec);
  $("#detail-spread").textContent = fmt(inst.ask - inst.bid, inst.prec);
  const active = state.alerts.filter((a) => a.symbol === inst.symbol && a.enabled && !isExpired(a));
  $("#detail-alerts").innerHTML = active.length
    ? active
        .map(
          (a) => `<div class="card"><div class="tile-top"><b>${a.name || a.symbol}</b>
            <span class="chip" style="margin-left:auto">${describe(a)}</span></div></div>`
        )
        .join("")
    : `<p class="empty" style="padding:14px">No active alerts for this instrument yet.</p>`;
}

function drawChart() {
  const inst = state.instruments.find((i) => i.symbol === state.selected);
  if (!inst) return;
  const canvas = $("#chart");
  const ctx = canvas.getContext("2d");
  const w = (canvas.width = canvas.clientWidth * 2);
  const h = (canvas.height = 300);
  const data = inst.history.slice(-(chartInterval === "15min" ? 24 : chartInterval === "1h" ? 48 : chartInterval === "4h" ? 72 : 96));
  const min = Math.min(...data), max = Math.max(...data);
  const range = max - min || 1;
  const up = data[data.length - 1] >= data[0];
  const color = up ? "#22c55e" : "#ef4444";

  ctx.clearRect(0, 0, w, h);
  const pt = (i) => [(i / (data.length - 1)) * w, h - 20 - ((data[i] - min) / range) * (h - 40)];

  // fill
  const grad = ctx.createLinearGradient(0, 0, 0, h);
  grad.addColorStop(0, up ? "rgba(34,197,94,0.25)" : "rgba(239,68,68,0.25)");
  grad.addColorStop(1, "rgba(0,0,0,0)");
  ctx.beginPath();
  ctx.moveTo(...pt(0));
  data.forEach((_, i) => ctx.lineTo(...pt(i)));
  ctx.lineTo(w, h); ctx.lineTo(0, h); ctx.closePath();
  ctx.fillStyle = grad; ctx.fill();

  // line
  ctx.beginPath();
  ctx.moveTo(...pt(0));
  data.forEach((_, i) => ctx.lineTo(...pt(i)));
  ctx.strokeStyle = color; ctx.lineWidth = 3; ctx.lineJoin = "round"; ctx.stroke();

  // last dot
  const [lx, ly] = pt(data.length - 1);
  ctx.beginPath(); ctx.arc(lx, ly, 7, 0, Math.PI * 2); ctx.fillStyle = color; ctx.fill();
  ctx.beginPath(); ctx.arc(lx, ly, 3, 0, Math.PI * 2); ctx.fillStyle = "#0f172a"; ctx.fill();
}

// ---------- Alert editor ----------

const CONDITION_TYPES = {
  above: "Price above",
  below: "Price below",
  crossesAbove: "Crosses above",
  crossesBelow: "Crosses below",
  bidAbove: "Bid reaches",
  bidBelow: "Bid falls to",
  askAbove: "Ask reaches",
  askBelow: "Ask falls to",
  changePercentAbove: "Change ≥ %",
  entersRange: "Enters range",
  leavesRange: "Leaves range",
};

function openAlertEdit() {
  $("#alert-title").textContent = `New alert · ${state.selected}`;
  $("#alert-name").value = "";
  $("#alert-expiry").value = "";
  $("#alert-enabled").checked = true;
  $("#alert-saved").classList.add("hidden");
  state.logic = "all";
  state.mode = "once";
  $("#conditions").innerHTML = "";
  addConditionRow();
  syncToggles();
  showScreen("alert-edit");
}

$("#alert-back").addEventListener("click", () => showScreen("detail"));
$("#fab-create") // bound in openDetail

function syncToggles() {
  document.querySelectorAll("#logic-toggle .seg").forEach((b) =>
    b.classList.toggle("active", b.dataset.logic === state.logic));
  document.querySelectorAll("#mode-toggle .seg").forEach((b) =>
    b.classList.toggle("active", b.dataset.mode === state.mode));
  $("#cooldown-row").classList.toggle("hidden", state.mode !== "repeating");
}

document.querySelectorAll("#logic-toggle .seg").forEach((b) =>
  b.addEventListener("click", () => { state.logic = b.dataset.logic; syncToggles(); }));
document.querySelectorAll("#mode-toggle .seg").forEach((b) =>
  b.addEventListener("click", () => { state.mode = b.dataset.mode; syncToggles(); }));
$("#cooldown").addEventListener("input", () => {
  state.cooldown = +$("#cooldown").value;
  $("#cooldown-val").textContent = `${state.cooldown}m`;
});

function addConditionRow() {
  const div = document.createElement("div");
  div.className = "cond-card";
  div.innerHTML = `
    <div class="cond-row">
      <select class="cond-type">${Object.entries(CONDITION_TYPES).map(([k, v]) => `<option value="${k}">${v}</option>`).join("")}</select>
      <button class="cond-del" title="Remove" aria-label="Remove condition">&times;</button>
    </div>
    <div class="cond-row">
      <input class="cond-v1" type="number" step="any" placeholder="Value" />
      <input class="cond-v2 hidden" type="number" step="any" placeholder="To" />
    </div>`;
  $("#conditions").appendChild(div);
  const typeSel = div.querySelector(".cond-type");
  typeSel.addEventListener("change", () => {
    const isRange = ["entersRange", "leavesRange"].includes(typeSel.value);
    div.querySelector(".cond-v2").classList.toggle("hidden", !isRange);
    div.querySelector(".cond-v1").placeholder = isRange ? "From" : "Value";
  });
  div.querySelector(".cond-del").addEventListener("click", () => {
    if ($("#conditions").children.length > 1) div.remove();
  });
}
$("#add-condition").addEventListener("click", addConditionRow);

$("#alert-save").addEventListener("click", () => {
  const inst = state.instruments.find((i) => i.symbol === state.selected);
  const conditions = [];
  $("#conditions").querySelectorAll(".cond-card").forEach((card) => {
    const type = card.querySelector(".cond-type").value;
    const v1 = parseFloat(card.querySelector(".cond-v1").value);
    const v2 = parseFloat(card.querySelector(".cond-v2").value);
    const isRange = ["entersRange", "leavesRange"].includes(type);
    if (isRange) {
      if (!isNaN(v1) && !isNaN(v2) && v2 > v1) conditions.push({ type, value: v1, value2: v2 });
    } else if (!isNaN(v1)) {
      conditions.push({ type, value: v1, referencePrice: type === "changePercentAbove" ? inst.price : undefined });
    }
  });
  if (!conditions.length) return;

  const expiryRaw = $("#alert-expiry").value;
  state.alerts.push({
    id: `a${Date.now()}`,
    userId: state.email,
    symbol: state.selected,
    name: $("#alert-name").value.trim() || null,
    conditions,
    logic: state.logic,
    mode: state.mode,
    cooldownMinutes: state.mode === "repeating" ? state.cooldown : 0,
    enabled: $("#alert-enabled").checked,
    expiresAt: expiryRaw ? new Date(expiryRaw).getTime() : null,
    lastTriggeredAt: null,
    createdAt: Date.now(),
  });
  $("#alert-saved").classList.remove("hidden");
  renderMarkets(); renderAlerts();
  setTimeout(() => showScreen("detail"), 700);
});

// ---------- Active alerts ----------

function isExpired(a) { return a.expiresAt && a.expiresAt < Date.now(); }

function describe(a) {
  return a.conditions.map((c) => {
    const label = CONDITION_TYPES[c.type] || c.type;
    if (c.type === "entersRange" || c.type === "leavesRange") return `${label} ${c.value}–${c.value2}`;
    if (c.type === "changePercentAbove") return `${label}${c.value}%`;
    return `${label} ${c.value}`;
  }).join(a.logic === "all" ? " AND " : " OR ");
}

function renderAlerts() {
  const list = $("#alerts-list");
  if (!state.alerts.length) {
    list.innerHTML = `<div class="empty"><svg viewBox="0 0 24 24" width="42" height="42" fill="none" stroke="var(--text-dim)" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/></svg>No alerts yet.<br>Search an instrument and create your first alert.</div>`;
    return;
  }
  list.innerHTML = state.alerts
    .map((a) => {
      const exp = isExpired(a);
      const status = exp ? ["expired", "Expired"] : a.enabled ? ["active", "Active"] : ["paused", "Paused"];
      const sub = [
        a.mode === "once" ? "One-time" : `Repeating${a.cooldownMinutes ? ` · ${a.cooldownMinutes}m cooldown` : ""}`,
        a.expiresAt ? `expires ${new Date(a.expiresAt).toLocaleString()}` : null,
      ].filter(Boolean).join(" · ");
      return `<div class="card">
        <div class="tile-top"><b>${a.name || a.symbol} · ${a.symbol}</b><span class="status ${status[0]}" style="margin-left:auto">${status[1]}</span></div>
        <div class="tile-sub">${describe(a)}</div>
        <div class="tile-sub">${sub}</div>
        <div class="tile-actions">
          <button class="mini-btn" data-toggle="${a.id}">${a.enabled ? "Disable" : "Enable"}</button>
          <button class="mini-btn danger" data-del="${a.id}">Delete</button>
        </div>
      </div>`;
    })
    .join("");
  list.querySelectorAll("[data-toggle]").forEach((b) =>
    b.addEventListener("click", () => {
      const a = state.alerts.find((x) => x.id === b.dataset.toggle);
      a.enabled = !a.enabled; renderAlerts(); renderMarkets(); renderDynamic();
    }));
  list.querySelectorAll("[data-del]").forEach((b) =>
    b.addEventListener("click", () => {
      state.alerts = state.alerts.filter((x) => x.id !== b.dataset.del);
      renderAlerts(); renderMarkets(); renderDynamic();
    }));
}

// ---------- Alert evaluation (demo of the backend evaluator) ----------

function evaluateAlerts() {
  for (const a of state.alerts) {
    if (!a.enabled || isExpired(a)) continue;
    const inst = state.instruments.find((i) => i.symbol === a.symbol);
    if (!inst) continue;
    const results = a.conditions.map((c) => {
      const price = inst.price;
      switch (c.type) {
        case "above": return price > c.value;
        case "below": return price < c.value;
        case "crossesAbove": return price > c.value;
        case "crossesBelow": return price < c.value;
        case "bidAbove": return inst.bid >= c.value;
        case "bidBelow": return inst.bid <= c.value;
        case "askAbove": return inst.ask >= c.value;
        case "askBelow": return inst.ask <= c.value;
        case "changePercentAbove": {
          const ref = c.referencePrice || inst.prevClose;
          return Math.abs((price - ref) / ref * 100) >= c.value;
        }
        case "entersRange": return price >= c.value && price <= c.value2;
        case "leavesRange": return price < c.value || price > c.value2;
        default: return false;
      }
    });
    const fired = a.logic === "all" ? results.every(Boolean) : results.some(Boolean);
    if (!fired) continue;

    // cooldown + one-time handling (dedup, like the backend)
    const now = Date.now();
    if (a.lastTriggeredAt && a.cooldownMinutes && now - a.lastTriggeredAt < a.cooldownMinutes * 60000) continue;
    if (a.lastTriggeredAt && a.mode === "once") continue;

    a.lastTriggeredAt = now;
    if (a.mode === "once") a.enabled = false;
    state.history.unshift({ id: `h${Date.now()}${Math.random()}`, alert: a, price: inst.price, at: now });
    showAlertBanner(a, inst.price);
    renderAlerts(); renderMarkets();
  }
  renderHistory();
}

// ---------- Foreground alert banner (mirrors AlertBanner widget) ----------

let bannerTimer;
function showAlertBanner(alert, price) {
  let el = document.getElementById("alert-banner");
  if (!el) {
    el = document.createElement("div");
    el.id = "alert-banner";
    el.className = "alert-banner";
    document.querySelector(".phone").appendChild(el);
  }
  el.innerHTML = `
    <div class="banner-icon"><svg viewBox="0 0 24 24" width="20" height="20" fill="none" stroke="var(--gold)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/></svg></div>
    <div><b>${alert.name || alert.symbol}</b><br><small>${alert.symbol} hit your target at ${price}</small></div>`;
  el.classList.add("show");
  clearTimeout(bannerTimer);
  bannerTimer = setTimeout(() => el.classList.remove("show"), 4000);
}

// ---------- History ----------

function renderHistory() {
  const list = $("#history-list");
  if (!state.history.length) {
    list.innerHTML = `<div class="empty"><svg viewBox="0 0 24 24" width="42" height="42" fill="none" stroke="var(--text-dim)" stroke-width="1.6" stroke-linecap="round"><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 3"/></svg>No triggered alerts yet.<br>The demo evaluator runs every 2 seconds against live simulated prices.</div>`;
    return;
  }
  list.innerHTML = state.history
    .slice(0, 50)
    .map((h) => `<div class="card">
      <div class="tile-top"><svg class="hist-icon" viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="var(--gold)" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8a6 6 0 0 0-12 0c0 7-3 9-3 9h18s-3-2-3-9"/><path d="M13.7 21a2 2 0 0 1-3.4 0"/></svg><b>${h.alert.name || h.alert.symbol} · ${h.alert.symbol}</b>
        <span class="chip" style="margin-left:auto">${new Date(h.at).toLocaleTimeString()}</span></div>
      <div class="tile-sub">Triggered at ${fmt(h.price, h.alert ? (state.instruments.find((i) => i.symbol === h.alert.symbol)?.prec ?? 2) : 2)} · ${describe(h.alert)}</div>
    </div>`)
    .join("");
}

// ---------- Dynamic refresh (prices ticking) ----------

function renderDynamic() {
  if ($("#screen-dashboard").classList.contains("active")) renderMarkets();
  if ($("#screen-detail").classList.contains("active")) { renderDetail(); drawChart(); }
}

// Init
renderAlerts();
renderHistory();
