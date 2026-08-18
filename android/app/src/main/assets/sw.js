// Flaxis S CV — Service Worker
// Cacheia só o "casco" da app (HTML/CSS/JS locais). Dados do Supabase
// e mídias NUNCA passam por aqui — ficam sempre atualizados.
const CACHE = 'flaxis-shell-v1';
const SHELL = ['./index.html', './view.html', './manifest.json'];

self.addEventListener('install', e => {
  e.waitUntil(caches.open(CACHE).then(c => c.addAll(SHELL)));
  self.skipWaiting();
});

self.addEventListener('activate', e => {
  e.waitUntil(
    caches.keys().then(keys => Promise.all(
      keys.filter(k => k !== CACHE).map(k => caches.delete(k))
    ))
  );
  self.clients.claim();
});

self.addEventListener('fetch', e => {
  const url = new URL(e.request.url);
  // Só intercepta pedidos do próprio domínio (shell). Supabase e Storage passam direto.
  if (url.origin !== location.origin) return;

  e.respondWith(
    caches.match(e.request).then(cached => {
      const network = fetch(e.request).then(res => {
        if (res.ok) caches.open(CACHE).then(c => c.put(e.request, res.clone()));
        return res;
      }).catch(() => cached);
      return cached || network;
    })
  );
});
