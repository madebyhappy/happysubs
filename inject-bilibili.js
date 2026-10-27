// Runs in the page's main world on bilibili.com.
//
// Bilibili's subtitle index only lists tracks for a signed-in viewer, and a
// fetch made from the content script comes back as if signed out: the player
// API answers with an empty subtitle list. The same request made from the
// page carries the viewer's session, so platform.js asks us to make it.
//
// Request:  YDS_BILI_FETCH  { id, url }          (detail is a JSON string)
// Reply:    YDS_BILI_RESULT { id, ok, text | error }
(function () {
  if (window.__ydsBiliInjected) return;
  window.__ydsBiliInjected = true;

  const ALLOWED = /^https:\/\/api\.bilibili\.com\//;

  function reply(detail) {
    window.dispatchEvent(new CustomEvent("YDS_BILI_RESULT", { detail: JSON.stringify(detail) }));
  }

  window.addEventListener("YDS_BILI_FETCH", async (e) => {
    let req;
    try { req = JSON.parse(e.detail); } catch { return; }
    if (!req || !req.id || !ALLOWED.test(String(req.url))) return;
    try {
      const r = await fetch(req.url, { credentials: "include" });
      reply({ id: req.id, ok: true, text: await r.text() });
    } catch (err) {
      reply({ id: req.id, ok: false, error: String((err && err.message) || err) });
    }
  });

  window.dispatchEvent(new CustomEvent("YDS_BILI_READY"));
})();
