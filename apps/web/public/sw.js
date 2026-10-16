/* No API caching, POST interception, background sync, or mutation replay. */
const CACHE='tani-static-v1';
const SHELL=['/offline.html','/offline.js','/icon-192.png','/icon-512.png','/icon-maskable.png','/icon.svg'];
self.addEventListener('install',event=>event.waitUntil(caches.open(CACHE).then(c=>c.addAll(SHELL))));
self.addEventListener('activate',event=>event.waitUntil(caches.keys().then(keys=>Promise.all(keys.filter(k=>k!==CACHE).map(k=>caches.delete(k)))).then(()=>self.clients.claim())));
self.addEventListener('fetch',event=>{
 const req=event.request,url=new URL(req.url);
 if(req.method!=='GET'||url.origin!==self.location.origin||url.pathname.startsWith('/api/'))return;
 if(req.mode==='navigate'){event.respondWith(fetch(req).catch(()=>caches.match('/offline.html')));return;}
 if(url.pathname.startsWith('/assets/')||SHELL.includes(url.pathname))event.respondWith(caches.open(CACHE).then(async cache=>{const cached=await cache.match(req);if(cached)return cached;const response=await fetch(req);if(response.ok)await cache.put(req,response.clone());return response;}));
});
self.addEventListener('push',event=>{
 let payload={};try{payload=event.data?event.data.json():{};}catch{payload={};}
 event.waitUntil(self.registration.showNotification('Kelompok Tani Podokoyo · Pengingat penjualan',{body:typeof payload.body==='string'?payload.body:'Konfirmasikan pencatatan penjualan hari ini.',icon:'/icon-192.png',badge:'/icon-192.png',tag:'sales-reminder',data:{url:'/dashboard/sales'}}));
});
self.addEventListener('notificationclick',event=>{event.notification.close();event.waitUntil(self.clients.matchAll({type:'window',includeUncontrolled:true}).then(async clients=>{const client=clients.find(c=>new URL(c.url).origin===self.location.origin);if(client){await client.navigate('/dashboard/sales');return client.focus();}return self.clients.openWindow('/dashboard/sales');}));});
