// CCIE Study Hub - minimal service worker
// 元エクスポートには sw.js が含まれていなかったため、PWA 登録の 404 を避けるための
// 最小構成として用意。オフラインキャッシュは行わず、常にネットワークへパススルーする。
// （オフライン対応が必要になったらここに cache 戦略を追加する）

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(self.clients.claim());
});

self.addEventListener('fetch', (event) => {
  // ネットワーク優先のパススルー（キャッシュなし）
  return;
});
