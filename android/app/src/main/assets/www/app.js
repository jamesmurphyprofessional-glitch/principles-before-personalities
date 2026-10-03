/* Principles Before Personalities — offline web reader (vanilla JS, no dependencies).
   Works from file://, from file:///android_asset/ inside the Android WebView, and when hosted (PWA). */
(function () {
  "use strict";

  var PENS = ["yellow", "amber", "pink", "green", "blue"];
  var STORE_KEY = "pbp.state.v1";
  var $ = function (id) { return document.getElementById(id); };

  // ---------- Storage (localStorage with graceful fallback) ----------
  var storage = (function () {
    try {
      var k = "__pbp_probe__";
      window.localStorage.setItem(k, "1");
      window.localStorage.removeItem(k);
      return window.localStorage;
    } catch (e) {
      var mem = {};
      return {
        getItem: function (key) { return Object.prototype.hasOwnProperty.call(mem, key) ? mem[key] : null; },
        setItem: function (key, v) { mem[key] = String(v); },
        removeItem: function (key) { delete mem[key]; },
        _memory: true
      };
    }
  })();

  function uuid() {
    try { if (window.crypto && crypto.randomUUID) return crypto.randomUUID(); } catch (e) { /* fall through */ }
    var b = new Uint8Array(16);
    if (window.crypto && crypto.getRandomValues) crypto.getRandomValues(b);
    else for (var i = 0; i < 16; i++) b[i] = Math.floor(Math.random() * 256);
    b[6] = (b[6] & 0x0f) | 0x40; b[8] = (b[8] & 0x3f) | 0x80;
    var h = Array.prototype.map.call(b, function (x) { return (x + 256).toString(16).slice(1); }).join("");
    return h.slice(0, 8) + "-" + h.slice(8, 12) + "-" + h.slice(12, 16) + "-" + h.slice(16, 20) + "-" + h.slice(20);
  }

  // ---------- Data ----------
  var bundled = (window.LIBRARY && window.LIBRARY.books) ? window.LIBRARY.books : [];
  var saved = null;
  try { saved = JSON.parse(storage.getItem(STORE_KEY) || "null"); } catch (e) { saved = null; }
  saved = saved || {};

  var state = {
    books: bundled.concat(Array.isArray(saved.userBooks) ? saved.userBooks : []),
    highlights: Array.isArray(saved.highlights) ? saved.highlights : [],
    ribbons: Array.isArray(saved.ribbons) ? saved.ribbons : [],
    notes: Array.isArray(saved.notes) ? saved.notes : [],
    pen: PENS.indexOf(saved.pen) >= 0 ? saved.pen : "yellow",
    tool: ["select", "marker", "eraser"].indexOf(saved.tool) >= 0 ? saved.tool : "select",
    place: saved.place || null,
    searchText: "",
    searchHit: -1,
    status: ""
  };
  var ui = {
    openBooks: {},
    marksOpen: false,
    filter: "",
    pending: null,          // {bookId, pageId, start, end}
    hits: [],
    hitsKey: "",
    lastPageKey: "",
    lastChapterKey: ""
  };

  function placeValid(p) {
    if (!p) return false;
    var b = bookById(p.bookId);
    if (!b) return false;
    return b.chapters.some(function (c) { return c.pages.some(function (pg) { return pg.id === p.pageId; }); });
  }
  function bookById(id) {
    for (var i = 0; i < state.books.length; i++) if (state.books[i].id === id) return state.books[i];
    return null;
  }
  if (!placeValid(state.place)) {
    var fb = state.books[0];
    state.place = fb && fb.chapters[0] && fb.chapters[0].pages[0]
      ? { bookId: fb.id, pageId: fb.chapters[0].pages[0].id } : { bookId: "", pageId: "" };
  }
  ui.openBooks[state.place.bookId] = true;

  var saveTimer = null;
  function save() {
    clearTimeout(saveTimer); saveTimer = null;
    var bundledIds = {};
    bundled.forEach(function (b) { bundledIds[b.id] = true; });
    var data = {
      highlights: state.highlights,
      ribbons: state.ribbons,
      place: state.place,
      userBooks: state.books.filter(function (b) { return !bundledIds[b.id]; }),
      pen: state.pen,
      tool: state.tool,
      notes: state.notes
    };
    try { storage.setItem(STORE_KEY, JSON.stringify(data)); }
    catch (e) { setStatus("Could not save — device storage is full."); }
  }
  function saveSoon() { clearTimeout(saveTimer); saveTimer = setTimeout(save, 350); }
  window.addEventListener("pagehide", function () { if (saveTimer) save(); });
  document.addEventListener("visibilitychange", function () { if (document.visibilityState === "hidden" && saveTimer) save(); });

  // ---------- Derived ----------
  function currentBook() { return bookById(state.place.bookId); }
  function flatPages() {
    var b = currentBook(); if (!b) return [];
    var out = [];
    b.chapters.forEach(function (c) { c.pages.forEach(function (p) { out.push({ chapter: c, page: p }); }); });
    return out;
  }
  function currentIndex(flat) {
    flat = flat || flatPages();
    for (var i = 0; i < flat.length; i++) if (flat[i].page.id === state.place.pageId) return i;
    return 0;
  }
  function current() {
    var flat = flatPages();
    if (!flat.length) return null;
    var i = currentIndex(flat);
    return { flat: flat, index: i, chapter: flat[i].chapter, page: flat[i].page, book: currentBook() };
  }
  function plain(page) { return page.paragraphs.join("\n\n"); }
  function currentRibbon() {
    for (var i = 0; i < state.ribbons.length; i++) {
      var r = state.ribbons[i];
      if (r.bookId === state.place.bookId && r.pageId === state.place.pageId) return r;
    }
    return null;
  }
  function pageNotes() {
    return state.notes.filter(function (n) { return n.bookId === state.place.bookId && n.pageId === state.place.pageId; })
      .sort(function (a, b) { return a.z - b.z; });
  }
  function pageHighlights(pageId) {
    return state.highlights.filter(function (h) { return h.bookId === state.place.bookId && h.pageId === pageId; })
      .sort(function (a, b) { return a.start - b.start; });
  }

  // ---------- Navigation ----------
  function open(bookId, pageId) {
    ui.pending = null;
    state.place = { bookId: bookId, pageId: pageId };
    save();
    render();
  }
  function go(delta) {
    var flat = flatPages(); if (!flat.length) return;
    var next = Math.min(Math.max(currentIndex(flat) + delta, 0), flat.length - 1);
    open(state.place.bookId, flat[next].page.id);
  }
  function jumpToBookPage(label) {
    var t = String(label || "").trim(); if (!t) return;
    var flat = flatPages(), match = null;
    for (var i = 0; i < flat.length && !match; i++) if (flat[i].page.numberLabel === t && flat[i].chapter.part === "The Book") match = flat[i];
    for (var j = 0; j < flat.length && !match; j++) if (flat[j].page.numberLabel === t) match = flat[j];
    if (match) open(state.place.bookId, match.page.id);
    else { setStatus("No page " + t + " in this book."); renderNav(); }
  }
  function neighborChapter(offset) {
    var c = current(); if (!c) return null;
    var idx = c.book.chapters.indexOf(c.chapter);
    var n = idx + offset;
    return (n >= 0 && n < c.book.chapters.length) ? c.book.chapters[n] : null;
  }

  // ---------- Highlights ----------
  function subtract(mark, s, e) {
    if (!(mark.start < e && s < mark.end)) return [mark];
    var pieces = [];
    if (mark.start < s) pieces.push({ id: uuid(), bookId: mark.bookId, pageId: mark.pageId, start: mark.start, end: s, color: mark.color });
    if (e < mark.end) pieces.push({ id: uuid(), bookId: mark.bookId, pageId: mark.pageId, start: e, end: mark.end, color: mark.color });
    return pieces;
  }
  function applyHighlight(sel, color) {
    if (!sel || sel.end <= sel.start) return;
    var kept = [];
    state.highlights.forEach(function (m) {
      if (m.bookId === sel.bookId && m.pageId === sel.pageId) kept.push.apply(kept, subtract(m, sel.start, sel.end));
      else kept.push(m);
    });
    // Merge with touching/overlapping marks of the same color so highlights stay clean.
    var s = sel.start, e = sel.end;
    kept = kept.filter(function (m) {
      if (m.bookId === sel.bookId && m.pageId === sel.pageId && m.color === color && (m.end === s || m.start === e)) {
        s = Math.min(s, m.start); e = Math.max(e, m.end); return false;
      }
      return true;
    });
    kept.push({ id: uuid(), bookId: sel.bookId, pageId: sel.pageId, start: s, end: e, color: color });
    state.highlights = kept;
    save();
  }
  function erase(sel) {
    if (!sel || sel.end <= sel.start) return;
    var out = [];
    state.highlights.forEach(function (m) {
      if (m.bookId === sel.bookId && m.pageId === sel.pageId) out.push.apply(out, subtract(m, sel.start, sel.end));
      else out.push(m);
    });
    state.highlights = out;
    save();
  }
  function validPending() {
    var p = ui.pending;
    return p && p.bookId === state.place.bookId && p.pageId === state.place.pageId && p.end > p.start ? p : null;
  }
  function chooseColor(pen) {
    state.pen = pen;
    state.tool = "marker";
    var sel = validPending();
    if (!sel) { setStatus("Select some text, then pick a color."); save(); renderToolbar(); return; }
    setStatus("");
    applyHighlight(sel, pen);
    clearSelection();
    renderPage(false); renderToolbar();
  }
  function eraseSelection() {
    state.tool = "eraser";
    var sel = validPending();
    if (sel) { erase(sel); clearSelection(); renderPage(false); }
    else save();
    renderToolbar();
  }
  function clearSelection() {
    ui.pending = null;
    try { var s = window.getSelection(); if (s) s.removeAllRanges(); } catch (e) { /* ignore */ }
    updateSelBar();
  }

  // ---------- Ribbons & notes ----------
  function toggleRibbon() {
    var c = current(); if (!c) return;
    var existing = currentRibbon();
    if (existing) {
      state.ribbons = state.ribbons.filter(function (r) { return r.id !== existing.id; });
      if (existing.color !== state.pen) state.ribbons.push({ id: uuid(), bookId: state.place.bookId, pageId: state.place.pageId, color: state.pen });
    } else {
      state.ribbons.push({ id: uuid(), bookId: state.place.bookId, pageId: state.place.pageId, color: state.pen });
    }
    save();
    renderRibbon(); renderToolbar(); renderSidebar();
  }
  function addNote() {
    var c = current(); if (!c) return;
    var count = pageNotes().length;
    var small = window.innerWidth < 600;
    var maxZ = state.notes.reduce(function (m, n) { return Math.max(m, n.z || 0); }, 0);
    var note = {
      id: uuid(), bookId: state.place.bookId, pageId: state.place.pageId, text: "", color: state.pen,
      x: small ? Math.min(0.7, 0.5 + (count % 3) * 0.06) : Math.min(0.78, 0.56 + (count % 3) * 0.06),
      y: Math.min(0.7, (small ? 0.18 : 0.28) + (count % 4) * 0.08),
      width: 210, height: 160, z: maxZ + 1
    };
    state.notes.push(note);
    save();
    renderNotes(note.id);
    renderSidebar();
  }
  function deleteNote(id) {
    state.notes = state.notes.filter(function (n) { return n.id !== id; });
    save();
    renderNotes(); renderSidebar();
  }

  // ---------- Search ----------
  function computeHits() {
    var needle = state.searchText.trim();
    var key = state.place.bookId + "\u0000" + needle.toLowerCase();
    if (key === ui.hitsKey) return ui.hits;
    ui.hitsKey = key;
    ui.hits = [];
    var b = currentBook();
    if (needle.length < 2 || !b) return ui.hits;
    var n = needle.toLowerCase();
    outer:
    for (var ci = 0; ci < b.chapters.length; ci++) {
      var ch = b.chapters[ci];
      for (var pi = 0; pi < ch.pages.length; pi++) {
        var hay = plain(ch.pages[pi]).toLowerCase(), from = 0, at;
        while ((at = hay.indexOf(n, from)) !== -1) {
          ui.hits.push({ pageId: ch.pages[pi].id, location: at, length: needle.length });
          from = at + Math.max(n.length, 1);
          if (ui.hits.length >= 500) break outer;
        }
      }
    }
    return ui.hits;
  }
  function jumpToSearch(delta) {
    var hits = computeHits(); if (!hits.length) { renderSearch(); return; }
    if (state.searchHit < 0) state.searchHit = delta > 0 ? 0 : hits.length - 1;
    else state.searchHit = (state.searchHit + delta + hits.length) % hits.length;
    var h = hits[state.searchHit];
    ui.scrollToFind = true;
    if (h.pageId !== state.place.pageId) open(state.place.bookId, h.pageId);
    else { renderPage(false); renderSearch(); }
  }
  function currentFind() {
    var hits = computeHits();
    if (state.searchHit < 0 || state.searchHit >= hits.length) return null;
    var h = hits[state.searchHit];
    return h.pageId === state.place.pageId ? { start: h.location, end: h.location + h.length } : null;
  }

  // ---------- Import ----------
  function isImportHeading(line) {
    if (line.charAt(0) === "#" && line.length < 80) return true;
    var letters = line.match(/\p{L}/gu) || [];
    if (letters.length < 4 || line.length > 70 || /\.$/.test(line)) return false;
    return letters.every(function (ch) { return /\p{Lu}/u.test(ch); });
  }
  function chunk(paragraphs) {
    var pages = [], cur = [], words = 0;
    paragraphs.forEach(function (p) {
      var count = p.split(/\s+/).filter(Boolean).length;
      if (cur.length && words + count > 230 && words > 80) { pages.push(cur); cur = [p]; words = count; }
      else { cur.push(p); words += count; }
    });
    if (cur.length) pages.push(cur);
    return pages.length ? pages : [[""]];
  }
  function bookFromText(text, title) {
    var lines = text.replace(/\r\n?/g, "\n").split("\n");
    var chapters = [], name = "Text", buffer = [];
    function flush() {
      var body = buffer.join("\n").trim(); buffer = [];
      if (!body) return;
      var paras = body.split(/\n\s*\n/).map(function (p) { return p.replace(/\n/g, " ").trim(); }).filter(Boolean);
      chapters.push([name, paras]);
    }
    lines.forEach(function (line) {
      var t = line.trim();
      if (isImportHeading(t)) { flush(); name = t.replace(/^#+\s*/, "") || "Text"; return; }
      buffer.push(line);
    });
    flush();
    if (!chapters.length) chapters = [[title, [text.trim() || "(empty)"]]];
    var bookId = "user-" + uuid().toLowerCase();
    return {
      id: bookId, title: title, subtitle: "Imported text",
      note: "A text you imported. Highlights and page markers stay on this device.",
      chapters: chapters.map(function (item, index) {
        return {
          id: bookId + "-c" + index, title: item[0], part: "Imported",
          pages: chunk(item[1]).map(function (paras, pi) {
            return { id: bookId + "-" + index + "-" + pi, numberLabel: String(pi + 1), paragraphs: paras };
          })
        };
      })
    };
  }
  function decodeText(buf) {
    var u8 = new Uint8Array(buf);
    try {
      if (u8[0] === 0xFF && u8[1] === 0xFE) return new TextDecoder("utf-16le").decode(u8);
      if (u8[0] === 0xFE && u8[1] === 0xFF) return new TextDecoder("utf-16be").decode(u8);
      return new TextDecoder("utf-8").decode(u8);
    } catch (e) { return null; }
  }
  function importFile(file) {
    if (!file) return;
    var reader = new FileReader();
    reader.onload = function () {
      var text = decodeText(reader.result);
      if (text == null || !text.trim()) { setStatus("Could not read that file."); return; }
      var title = file.name.replace(/\.[^.]+$/, "") || "Imported text";
      var book = bookFromText(text, title);
      state.books.push(book);
      ui.openBooks[book.id] = true;
      state.place = { bookId: book.id, pageId: book.chapters[0].pages[0].id };
      setStatus("Imported " + title + ".");
      save();
      closeDrawer();
      render();
    };
    reader.onerror = function () { setStatus("Could not read that file."); };
    reader.readAsArrayBuffer(file);
  }
  function removeBook(id) {
    var b = bookById(id); if (!b || !/^user-/.test(id)) return;
    if (!window.confirm("Remove “" + b.title + "” and its highlights, marks and notes from this device?")) return;
    state.books = state.books.filter(function (x) { return x.id !== id; });
    state.highlights = state.highlights.filter(function (x) { return x.bookId !== id; });
    state.ribbons = state.ribbons.filter(function (x) { return x.bookId !== id; });
    state.notes = state.notes.filter(function (x) { return x.bookId !== id; });
    if (state.place.bookId === id) {
      var f = state.books[0];
      state.place = f ? { bookId: f.id, pageId: f.chapters[0].pages[0].id } : { bookId: "", pageId: "" };
    }
    setStatus("Removed " + b.title + ".");
    save(); render();
  }

  // ---------- Status ----------
  var statusTimer = null;
  function setStatus(msg) {
    state.status = msg || "";
    var el = $("status"); if (el) el.textContent = state.status;
    clearTimeout(statusTimer);
    if (msg) statusTimer = setTimeout(function () { state.status = ""; if (el) el.textContent = ""; }, 4000);
    showToast(msg);
  }
  var toastEl = null, toastTimer = null;
  function showToast(msg) {
    // On phones the sidebar status is hidden in the drawer; show a brief toast instead.
    if (!msg || window.innerWidth > 860) return;
    if (!toastEl) {
      toastEl = document.createElement("div");
      toastEl.style.cssText = "position:fixed;left:50%;transform:translateX(-50%);bottom:calc(120px + env(safe-area-inset-bottom,0px));z-index:60;background:rgba(24,34,50,.97);color:#73dbf2;padding:8px 14px;border-radius:999px;font-size:13px;box-shadow:0 6px 20px rgba(0,0,0,.4);max-width:90vw;text-align:center;pointer-events:none";
      document.body.appendChild(toastEl);
    }
    toastEl.textContent = msg; toastEl.hidden = false;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { toastEl.hidden = true; }, 2600);
  }

  // ---------- Rendering helpers ----------
  function el(tag, cls, text) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  }
  function isHeading(p) {
    if (p.indexOf("Chapter ") === 0 && p.length < 20) return true;
    var letters = p.match(/\p{L}/gu) || [];
    return p.length < 48 && letters.length > 2 && letters.every(function (ch) { return /\p{Lu}/u.test(ch); });
  }
  function penCss(name) { return "var(--" + (PENS.indexOf(name) >= 0 ? name : "yellow") + ")"; }

  // ---------- Render: sidebar ----------
  function groups(book) {
    var order = [], map = {};
    book.chapters.forEach(function (c) {
      if (!map[c.part]) { map[c.part] = []; order.push(c.part); }
      map[c.part].push(c);
    });
    return order.map(function (p) { return [p, map[p]]; });
  }
  function chapterPageSet(ch) { var s = {}; ch.pages.forEach(function (p) { s[p.id] = true; }); return s; }

  function renderSidebar() {
    var list = $("libraryList");
    var q = ui.filter.trim().toLowerCase();
    var cur = current();
    list.textContent = "";
    state.books.forEach(function (book) {
      var gs = groups(book).map(function (g) {
        var kept = q ? g[1].filter(function (c) { return c.title.toLowerCase().indexOf(q) >= 0; }) : g[1];
        return [g[0], kept];
      }).filter(function (g) { return g[1].length; });
      if (q && !gs.length) return;
      var expanded = q ? gs.length > 0 : !!ui.openBooks[book.id];
      var sec = el("div", "book" + (state.place.bookId === book.id ? " current" : ""));
      var head = el("div", "book-head");
      var chev = el("button", "chev" + (expanded ? " open" : ""), "\u25B6");
      chev.setAttribute("aria-label", (expanded ? "Collapse " : "Expand ") + book.title);
      chev.setAttribute("aria-expanded", String(expanded));
      chev.onclick = function () { ui.openBooks[book.id] = !ui.openBooks[book.id]; renderSidebar(); };
      var openBtn = el("button", "book-open");
      openBtn.title = book.note || "";
      openBtn.appendChild(el("div", "book-title", book.title));
      openBtn.appendChild(el("div", "book-sub", book.subtitle));
      openBtn.onclick = function () {
        ui.openBooks[book.id] = true;
        var p = book.chapters[0] && book.chapters[0].pages[0];
        if (p) { open(book.id, p.id); closeDrawer(); }
      };
      head.appendChild(chev); head.appendChild(openBtn);
      if (/^user-/.test(book.id)) {
        var rm = el("button", "mini-btn", "\u2715");
        rm.title = "Remove this imported text"; rm.setAttribute("aria-label", "Remove " + book.title);
        rm.onclick = function () { removeBook(book.id); };
        head.appendChild(rm);
      }
      sec.appendChild(head);
      if (expanded) {
        gs.forEach(function (g) {
          if (gs.length > 1) sec.appendChild(el("div", "part-label", g[0]));
          g[1].forEach(function (ch) { sec.appendChild(chapterRow(book, ch, cur)); });
        });
      }
      list.appendChild(sec);
    });
    if (q && !list.children.length) list.appendChild(el("div", "empty-hint", "No chapters match “" + ui.filter.trim() + "”."));
    if (state.ribbons.length) list.appendChild(marksSection());
  }
  function chapterRow(book, ch, cur) {
    var selected = cur && cur.chapter.id === ch.id && state.place.bookId === book.id;
    var ids = chapterPageSet(ch);
    var mark = null;
    for (var i = 0; i < state.ribbons.length; i++) { var r = state.ribbons[i]; if (r.bookId === book.id && ids[r.pageId]) { mark = r; break; } }
    var hasNote = state.notes.some(function (n) { return n.bookId === book.id && ids[n.pageId]; });
    var row = el("button", "chapter-row" + (selected ? " selected" : ""));
    row.dataset.key = book.id + "/" + ch.id;
    var dot = el("span", "dot");
    if (mark) dot.style.background = penCss(mark.color);
    row.appendChild(dot);
    row.appendChild(el("span", "chapter-name", ch.title));
    if (hasNote) { var ni = el("span", "note-ind"); ni.title = "Has sticky notes"; row.appendChild(ni); }
    if (ch.part === "The Book" && ch.pages[0]) row.appendChild(el("span", "page-lbl", ch.pages[0].numberLabel));
    row.onclick = function () {
      ui.openBooks[book.id] = true;
      if (ch.pages[0]) { open(book.id, ch.pages[0].id); closeDrawer(); }
    };
    return row;
  }
  function locate(r) {
    var b = bookById(r.bookId); if (!b) return null;
    for (var i = 0; i < b.chapters.length; i++) {
      var pages = b.chapters[i].pages;
      for (var j = 0; j < pages.length; j++) if (pages[j].id === r.pageId) return { book: b, chapter: b.chapters[i], page: pages[j] };
    }
    return null;
  }
  function marksSection() {
    var wrap = el("div", "marks");
    var head = el("button", "marks-head");
    head.appendChild(el("span", "chev" + (ui.marksOpen ? " open" : ""), "\u25B6"));
    head.appendChild(el("span", null, "Marked pages"));
    head.appendChild(el("span", "count", String(state.ribbons.length)));
    head.setAttribute("aria-expanded", String(ui.marksOpen));
    head.onclick = function () { ui.marksOpen = !ui.marksOpen; renderSidebar(); };
    wrap.appendChild(head);
    if (ui.marksOpen) {
      state.ribbons.forEach(function (r) {
        var loc = locate(r); if (!loc) return;
        var row = el("button", "mark-row");
        var dot = el("span", "dot"); dot.style.background = penCss(r.color);
        row.appendChild(dot);
        row.appendChild(el("span", "chapter-name", loc.chapter.title));
        if (state.books.length > 1 && loc.book.id !== state.place.bookId) row.appendChild(el("span", "book-tag", loc.book.title));
        row.appendChild(el("span", "page-lbl", loc.page.numberLabel));
        row.onclick = function () { ui.openBooks[loc.book.id] = true; open(loc.book.id, loc.page.id); closeDrawer(); };
        wrap.appendChild(row);
      });
    }
    return wrap;
  }
  function scrollSidebarToCurrent() {
    var c = current(); if (!c) return;
    var key = state.place.bookId + "/" + c.chapter.id;
    if (key === ui.lastChapterKey) return;
    ui.lastChapterKey = key;
    var rows = $("libraryList").querySelectorAll(".chapter-row");
    for (var i = 0; i < rows.length; i++) {
      if (rows[i].dataset.key === key) {
        var list = $("libraryList"), r = rows[i];
        var top = r.offsetTop - list.clientHeight / 2 + r.offsetHeight / 2;
        list.scrollTop = Math.max(0, top);
        break;
      }
    }
  }

  // ---------- Render: toolbar ----------
  function buildPenButtons(container, onPick, isSelBar) {
    container.textContent = "";
    PENS.forEach(function (p) {
      var b = el("button", "pen");
      b.dataset.pen = p;
      b.title = "Highlight the selection in " + p;
      b.setAttribute("aria-label", "Highlight " + p);
      var dot = el("i"); dot.style.background = penCss(p);
      b.appendChild(dot);
      if (isSelBar) {
        // Act on pointerdown so the native text selection is still alive on touch devices.
        b.addEventListener("pointerdown", function (e) { e.preventDefault(); onPick(p); });
        b.addEventListener("click", function (e) { e.preventDefault(); });
      } else {
        b.addEventListener("mousedown", function (e) { e.preventDefault(); }); // keep selection on desktop
        b.onclick = function () { onPick(p); };
      }
      container.appendChild(b);
    });
  }
  function renderToolbar() {
    var c = current();
    $("chapterTitle").textContent = c ? c.chapter.title : "Principles Before Personalities";
    var where = c ? c.book.title : "";
    if (c && c.chapter.part === "The Book") where += "  \u00B7  page " + c.page.numberLabel;
    $("whereLine").textContent = where;
    document.title = c ? c.chapter.title + " — Principles Before Personalities" : "Principles Before Personalities";
    Array.prototype.forEach.call($("penTray").children, function (b) { b.classList.toggle("on", b.dataset.pen === state.pen); });
    Array.prototype.forEach.call(document.querySelectorAll(".tool-btn"), function (b) { b.classList.toggle("on", b.dataset.tool === state.tool); });
    var r = currentRibbon();
    var markBtn = $("markBtn"), icon = $("markIcon");
    if (r) { markBtn.style.color = penCss(r.color); icon.setAttribute("fill", "currentColor"); markBtn.title = "Unmark this page"; }
    else { markBtn.style.color = ""; icon.setAttribute("fill", "none"); markBtn.title = "Mark this page"; }
  }
  function renderSearch() {
    var hits = computeHits();
    var box = $("searchBox");
    box.classList.toggle("has-query", state.searchText.trim().length > 0);
    var txt;
    if (state.searchText.trim().length < 2) txt = "";
    else if (!hits.length) txt = "0";
    else if (state.searchHit < 0) txt = (hits.length >= 500 ? "500+" : hits.length) + (hits.length === 1 ? " hit" : " hits");
    else txt = (state.searchHit + 1) + " / " + (hits.length >= 500 ? "500+" : hits.length);
    $("searchCount").textContent = txt;
    $("searchPrev").disabled = $("searchNext").disabled = !hits.length;
  }

  // ---------- Render: page ----------
  function renderPage(scrollTop) {
    var c = current();
    var text = $("pageText");
    text.textContent = "";
    if (!c) { text.appendChild(el("p", null, "No books found.")); $("pageFoot").textContent = ""; return; }
    var marks = pageHighlights(c.page.id);
    var find = currentFind();
    var cursor = 0;
    c.page.paragraphs.forEach(function (para, idx) {
      var p = el("p", isHeading(para) ? "heading" : null);
      var start = cursor, end = cursor + para.length;
      p.dataset.s = String(start);
      // boundaries within this paragraph
      var cuts = [start, end];
      marks.forEach(function (m) { if (m.start < end && m.end > start) { cuts.push(Math.max(m.start, start), Math.min(m.end, end)); } });
      if (find && find.start < end && find.end > start) cuts.push(Math.max(find.start, start), Math.min(find.end, end));
      cuts = cuts.filter(function (v, i, a) { return a.indexOf(v) === i; }).sort(function (a, b) { return a - b; });
      for (var i = 0; i < cuts.length - 1; i++) {
        var a = cuts[i], b = cuts[i + 1];
        if (b <= a) continue;
        var piece = para.slice(a - start, b - start);
        var color = null;
        for (var k = 0; k < marks.length; k++) if (marks[k].start <= a && marks[k].end >= b) { color = marks[k].color; break; }
        var inFind = find && find.start <= a && find.end >= b;
        if (!color && !inFind) { p.appendChild(document.createTextNode(piece)); continue; }
        var span = el("span", (color ? "hl hl-" + color : "") + (inFind ? " find" : ""));
        span.textContent = piece;
        p.appendChild(span);
      }
      if (!para.length) p.appendChild(document.createTextNode("\u200B"));
      text.appendChild(p);
      cursor = end + (idx < c.page.paragraphs.length - 1 ? 2 : 0);
    });
    $("pageFoot").textContent = c.chapter.part === "The Book"
      ? c.page.numberLabel
      : "Page " + c.page.numberLabel + " of " + c.chapter.pages.length;
    renderRibbon();
    renderNotes();
    var well = $("well");
    if (scrollTop) well.scrollTop = 0;
    if (ui.scrollToFind) {
      ui.scrollToFind = false;
      var f = text.querySelector(".find");
      if (f) {
        var wr = well.getBoundingClientRect(), fr = f.getBoundingClientRect();
        well.scrollTop += (fr.top - wr.top) - wr.height / 2 + fr.height / 2;
      }
    }
  }
  function renderRibbon() {
    var r = currentRibbon(), rib = $("ribbon");
    if (r) { rib.hidden = false; rib.style.background = penCss(r.color); }
    else rib.hidden = true;
  }

  // ---------- Render: sticky notes ----------
  function noteColor(name) { return "var(--note-" + (PENS.indexOf(name) >= 0 ? name : "yellow") + ")"; }
  function layoutNote(node, note) {
    var sheet = $("sheet");
    var W = Math.max(sheet.clientWidth, 1), H = Math.max(sheet.clientHeight, 1);
    var w = Math.min(note.width, W - 16), h = Math.min(note.height, Math.max(110, H - 16));
    var left = note.x * W - w / 2, top = note.y * H - h / 2;
    left = Math.min(Math.max(left, 4), W - w - 4);
    top = Math.min(Math.max(top, 4), H - h - 4);
    node.style.width = w + "px"; node.style.height = h + "px";
    node.style.left = left + "px"; node.style.top = top + "px";
    node.style.zIndex = String(note.z || 1);
    node.style.background = noteColor(note.color);
  }
  function findNote(id) { for (var i = 0; i < state.notes.length; i++) if (state.notes[i].id === id) return state.notes[i]; return null; }
  function renderNotes(focusId) {
    var layer = $("noteLayer");
    layer.textContent = "";
    pageNotes().forEach(function (note) {
      var node = el("div", "note");
      node.dataset.id = note.id;
      var head = el("div", "note-head");
      head.style.background = "rgba(0,0,0,0.05)";
      var drag = el("div", "note-drag"); drag.title = "Drag the note";
      head.appendChild(drag);
      var colors = el("div", "note-colors");
      PENS.forEach(function (p) {
        var cb = el("button", "note-color" + (note.color === p ? " on" : ""));
        cb.title = "Note color"; cb.setAttribute("aria-label", "Note color " + p);
        var i = el("i"); i.style.background = penCss(p); cb.appendChild(i);
        cb.onclick = function () {
          note.color = p; save();
          node.style.background = noteColor(p);
          Array.prototype.forEach.call(colors.children, function (x) { x.classList.toggle("on", x === cb); });
        };
        colors.appendChild(cb);
      });
      head.appendChild(colors);
      var del = el("button", "note-del", "\u2715"); del.title = "Remove note"; del.setAttribute("aria-label", "Remove note");
      del.onclick = function () {
        if (note.text.trim() && !window.confirm("Delete this note?")) return;
        deleteNote(note.id);
      };
      head.appendChild(del);
      node.appendChild(head);
      var ta = el("textarea");
      ta.placeholder = "Write a note\u2026";
      ta.value = note.text || "";
      ta.addEventListener("input", function () { note.text = ta.value; saveSoon(); });
      ta.addEventListener("blur", function () { if (saveTimer) save(); });
      ta.addEventListener("focus", function () { bringForward(note, node); });
      node.appendChild(ta);
      var rs = el("div", "note-resize", "\u2198"); rs.title = "Resize note";
      node.appendChild(rs);
      layoutNote(node, note);
      layer.appendChild(node);

      dragHandler(drag, function () { bringForward(note, node); }, function (dx, dy) {
        var sheet = $("sheet");
        var W = Math.max(sheet.clientWidth, 1), H = Math.max(sheet.clientHeight, 1);
        note.x = Math.min(0.92, Math.max(0.08, note.x + dx / W));
        note.y = Math.min(0.96, Math.max(0.04, note.y + dy / H));
        layoutNote(node, note);
      });
      dragHandler(rs, function () { bringForward(note, node); }, function (dx, dy) {
        note.width = Math.min(360, Math.max(150, note.width + dx));
        note.height = Math.min(420, Math.max(110, note.height + dy));
        // keep the top-left corner fixed while resizing (position is stored as the center)
        var sheet = $("sheet");
        note.x += (dx / 2) / Math.max(sheet.clientWidth, 1);
        note.y += (dy / 2) / Math.max(sheet.clientHeight, 1);
        layoutNote(node, note);
      });
      if (focusId === note.id) setTimeout(function () { try { ta.focus({ preventScroll: false }); } catch (e) { ta.focus(); } }, 30);
    });
  }
  function bringForward(note, node) {
    var maxZ = state.notes.reduce(function (m, n) { return Math.max(m, n.z || 0); }, 0);
    if ((note.z || 0) < maxZ) { note.z = maxZ + 1; node.style.zIndex = String(note.z); saveSoon(); }
  }
  function dragHandler(handle, onDown, onDelta) {
    var last = null, pid = null;
    handle.addEventListener("pointerdown", function (e) {
      e.preventDefault(); e.stopPropagation();
      last = { x: e.clientX, y: e.clientY }; pid = e.pointerId;
      try { handle.setPointerCapture(pid); } catch (err) { /* ignore */ }
      onDown();
    });
    handle.addEventListener("pointermove", function (e) {
      if (!last || e.pointerId !== pid) return;
      e.preventDefault();
      var dx = e.clientX - last.x, dy = e.clientY - last.y;
      last = { x: e.clientX, y: e.clientY };
      onDelta(dx, dy);
    });
    function end(e) {
      if (!last) return;
      last = null;
      try { handle.releasePointerCapture(e.pointerId); } catch (err) { /* ignore */ }
      save();
    }
    handle.addEventListener("pointerup", end);
    handle.addEventListener("pointercancel", end);
    handle.addEventListener("touchstart", function (e) { e.stopPropagation(); }, { passive: true });
  }

  // ---------- Render: nav bar ----------
  function renderNav() {
    var c = current();
    var flat = c ? c.flat : [];
    $("prevPage").disabled = !c || c.index === 0;
    $("nextPage").disabled = !c || c.index >= flat.length - 1;
    var pj = $("pageJump");
    if (document.activeElement !== pj) pj.value = c ? c.page.numberLabel : "";
    [["prevChapter", -1], ["nextChapter", 1]].forEach(function (pair) {
      var btn = $(pair[0]), n = neighborChapter(pair[1]);
      btn.textContent = pair[1] < 0 ? "\u2039  " + (n ? n.title : "Start") : (n ? n.title : "End") + "  \u203A";
      btn.disabled = !n;
      btn.title = n ? (pair[1] < 0 ? "Previous chapter: " : "Next chapter: ") + n.title : "";
    });
  }

  function updateSelBar() {
    var show = !!validPending();
    $("selBar").hidden = !show;
  }

  function render() {
    var key = state.place.bookId + "/" + state.place.pageId;
    var pageChanged = key !== ui.lastPageKey;
    ui.lastPageKey = key;
    if (pageChanged) ui.pending = null;
    renderToolbar();
    renderSearch();
    renderPage(pageChanged);
    renderNav();
    renderSidebar();
    scrollSidebarToCurrent();
    updateSelBar();
  }

  // ---------- Selection → character offsets ----------
  function pointOffset(node, off) {
    var text = $("pageText");
    if (node === text) {
      var kids = text.children;
      if (off >= kids.length) {
        var lastP = kids[kids.length - 1];
        return lastP ? +lastP.dataset.s + lastP.textContent.replace(/\u200B/g, "").length : 0;
      }
      return +kids[off].dataset.s;
    }
    var elNode = node.nodeType === 1 ? node : node.parentElement;
    var p = elNode && elNode.closest ? elNode.closest("p[data-s]") : null;
    if (!p || !text.contains(p)) return null;
    var r = document.createRange();
    r.setStart(p, 0);
    try { r.setEnd(node, off); } catch (e) { return null; }
    return +p.dataset.s + r.toString().replace(/\u200B/g, "").length;
  }
  function selectionOffsets() {
    var sel = window.getSelection();
    if (!sel || !sel.rangeCount || sel.isCollapsed) return null;
    var range = sel.getRangeAt(0), text = $("pageText");
    try { if (!range.intersectsNode(text)) return null; } catch (e) { return null; }
    var c = current(); if (!c) return null;
    var total = plain(c.page).length;
    var s = text.contains(range.startContainer) ? pointOffset(range.startContainer, range.startOffset) : 0;
    var e = text.contains(range.endContainer) ? pointOffset(range.endContainer, range.endOffset) : total;
    if (s == null || e == null) return null;
    if (e < s) { var t = s; s = e; e = t; }
    s = Math.max(0, s); e = Math.min(total, e);
    if (e <= s) return null;
    return { bookId: state.place.bookId, pageId: c.page.id, start: s, end: e };
  }

  // ---------- Drawer (phones) ----------
  function openDrawer() { $("app").classList.add("drawer-open"); $("scrim").hidden = false; scrollSidebarToCurrentForce(); }
  function closeDrawer() { $("app").classList.remove("drawer-open"); $("scrim").hidden = true; }
  function scrollSidebarToCurrentForce() { ui.lastChapterKey = ""; scrollSidebarToCurrent(); }
  window.pbpBack = function () {
    if ($("app").classList.contains("drawer-open")) { closeDrawer(); return true; }
    if (document.querySelector(".toolbar.searching")) { document.querySelector(".toolbar").classList.remove("searching"); return true; }
    if (validPending()) { clearSelection(); return true; }
    return false;
  };

  // ---------- Wire up ----------
  function init() {
    if (!bundled.length) {
      $("pageText").innerHTML = "<p>The library data could not be loaded (library-data.js is missing).</p>";
    }
    buildPenButtons($("penTray"), chooseColor, false);
    buildPenButtons($("selPens"), function (p) {
      var sel = validPending();
      state.pen = p;
      if (sel) { applyHighlight(sel, p); clearSelection(); renderPage(false); } else save();
      renderToolbar();
    }, true);
    $("selErase").addEventListener("pointerdown", function (e) {
      e.preventDefault();
      var sel = validPending();
      if (sel) { erase(sel); clearSelection(); renderPage(false); }
    });

    Array.prototype.forEach.call(document.querySelectorAll(".tool-btn"), function (b) {
      b.addEventListener("mousedown", function (e) { e.preventDefault(); });
      b.onclick = function () {
        var t = b.dataset.tool;
        if (t === "eraser") { eraseSelection(); return; }
        if (t === "marker") {
          state.tool = "marker";
          var sel = validPending();
          if (sel) { applyHighlight(sel, state.pen); clearSelection(); renderPage(false); }
        } else state.tool = t;
        save(); renderToolbar();
      };
    });
    $("markBtn").onclick = toggleRibbon;
    $("noteBtn").onclick = addNote;
    $("searchToggle").onclick = function () {
      var tb = document.querySelector(".toolbar");
      tb.classList.toggle("searching");
      if (tb.classList.contains("searching")) setTimeout(function () { $("searchInput").focus(); }, 30);
    };

    var searchTimer = null;
    $("searchInput").addEventListener("input", function (e) {
      state.searchText = e.target.value;
      state.searchHit = -1;
      clearTimeout(searchTimer);
      searchTimer = setTimeout(function () { renderSearch(); renderPage(false); }, 160);
    });
    $("searchInput").addEventListener("keydown", function (e) {
      if (e.key === "Enter") { e.preventDefault(); clearTimeout(searchTimer); jumpToSearch(e.shiftKey ? -1 : 1); }
      if (e.key === "Escape") { e.target.value = ""; state.searchText = ""; state.searchHit = -1; renderSearch(); renderPage(false); e.target.blur(); }
    });
    $("searchPrev").onclick = function () { jumpToSearch(-1); };
    $("searchNext").onclick = function () { jumpToSearch(1); };

    $("chapterFilter").addEventListener("input", function (e) { ui.filter = e.target.value; renderSidebar(); });

    $("prevPage").onclick = function () { go(-1); };
    $("nextPage").onclick = function () { go(1); };
    $("prevChapter").onclick = function () { var n = neighborChapter(-1); if (n) open(state.place.bookId, n.pages[0].id); };
    $("nextChapter").onclick = function () { var n = neighborChapter(1); if (n) open(state.place.bookId, n.pages[0].id); };
    var pj = $("pageJump");
    pj.addEventListener("keydown", function (e) { if (e.key === "Enter") { e.preventDefault(); jumpToBookPage(pj.value); pj.blur(); } });
    pj.addEventListener("focus", function () { setTimeout(function () { try { pj.select(); } catch (e) { /* ignore */ } }, 0); });
    pj.addEventListener("blur", function () { renderNav(); });

    $("openSidebar").onclick = openDrawer;
    $("closeSidebar").onclick = closeDrawer;
    $("scrim").onclick = closeDrawer;

    $("importBtn").onclick = function () { $("importFile").click(); };
    $("importFile").addEventListener("change", function (e) {
      var f = e.target.files && e.target.files[0];
      importFile(f);
      e.target.value = "";
    });

    // Text selection tracking
    document.addEventListener("selectionchange", function () {
      var off = selectionOffsets();
      if (off) { ui.pending = off; setStatus(""); }
      updateSelBar();
    });
    var well = $("well");
    well.addEventListener("pointerdown", function (e) {
      if (e.target.closest && e.target.closest(".note")) return;
      ui.pending = null;
      updateSelBar();
    });
    // Marker / eraser tools paint on release (mouse & pen). On touch, the floating bar is used.
    well.addEventListener("pointerup", function (e) {
      if (e.pointerType === "touch") return;
      if (e.target.closest && e.target.closest(".note")) return;
      setTimeout(function () {
        if (state.tool === "select") return;
        var off = selectionOffsets(); if (!off) return;
        if (state.tool === "marker") applyHighlight(off, state.pen); else erase(off);
        clearSelection();
        renderPage(false);
      }, 10);
    });

    // Swipe left/right to turn pages on touch screens
    var sw = null;
    well.addEventListener("touchstart", function (e) {
      if (e.touches.length !== 1 || (e.target.closest && e.target.closest(".note"))) { sw = null; return; }
      sw = { x: e.touches[0].clientX, y: e.touches[0].clientY, t: Date.now() };
    }, { passive: true });
    well.addEventListener("touchend", function (e) {
      if (!sw) return;
      var t = e.changedTouches[0], dx = t.clientX - sw.x, dy = t.clientY - sw.y, dt = Date.now() - sw.t;
      sw = null;
      var s = window.getSelection();
      if (s && !s.isCollapsed) return;
      if (Math.abs(dx) > 70 && Math.abs(dy) < 50 && dt < 600) go(dx < 0 ? 1 : -1);
    }, { passive: true });

    // Keyboard shortcuts
    document.addEventListener("keydown", function (e) {
      var tag = (e.target && e.target.tagName) || "";
      var typing = tag === "INPUT" || tag === "TEXTAREA" || (e.target && e.target.isContentEditable);
      var mod = e.metaKey || e.ctrlKey;
      if (mod && (e.key === "ArrowLeft" || e.key === "ArrowRight") && !typing) { e.preventDefault(); go(e.key === "ArrowRight" ? 1 : -1); return; }
      if (mod && (e.key === "m" || e.key === "M")) { e.preventDefault(); toggleRibbon(); return; }
      if (mod && (e.key === "g" || e.key === "G")) { e.preventDefault(); jumpToSearch(e.shiftKey ? -1 : 1); return; }
      if (mod && (e.key === "f" || e.key === "F")) {
        e.preventDefault();
        document.querySelector(".toolbar").classList.add("searching");
        $("searchInput").focus(); $("searchInput").select(); return;
      }
      if (mod && (e.key === "o" || e.key === "O")) { e.preventDefault(); $("importFile").click(); return; }
      if (typing) return;
      if (!mod && !e.altKey && (e.key === "ArrowLeft" || e.key === "ArrowRight")) {
        var s = window.getSelection();
        if (s && !s.isCollapsed) return;
        e.preventDefault(); go(e.key === "ArrowRight" ? 1 : -1);
      }
      if (e.key === "Escape") { if (!window.pbpBack()) clearSelection(); }
    });

    var resizeTimer = null;
    window.addEventListener("resize", function () {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(function () {
        Array.prototype.forEach.call($("noteLayer").children, function (node) {
          var n = findNote(node.dataset.id); if (n) layoutNote(node, n);
        });
      }, 80);
    });

    render();
    if (storage._memory) setStatus("Storage unavailable — changes won't be kept after closing.");

    if ("serviceWorker" in navigator && /^https?:$/.test(location.protocol)) {
      window.addEventListener("load", function () {
        navigator.serviceWorker.register("service-worker.js").catch(function () { /* offline cache optional */ });
      });
    }
  }

  // test hook (used by the automated smoke test; harmless in production)
  window.__pbp = { state: state, go: go, open: open, jumpToBookPage: jumpToBookPage, applyHighlight: applyHighlight, erase: erase,
    toggleRibbon: toggleRibbon, addNote: addNote, computeHits: function () { return computeHits(); }, jumpToSearch: jumpToSearch,
    bookFromText: bookFromText, current: current, save: save, setSearch: function (t) { state.searchText = t; state.searchHit = -1; renderSearch(); } };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", init);
  else init();
})();
