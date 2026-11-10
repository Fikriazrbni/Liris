const ports = new Map();
chrome.runtime.onMessage.addListener((message, sender, reply) => {
  if (!sender.tab || sender.frameId !== 0 || message?.kind !== 'liris-snapshot') return;
  const url = new URL(sender.url);
  if (!['music.youtube.com', 'www.youtube.com', 'youtube.com'].includes(url.hostname) || url.protocol !== 'https:') return;
  const id = sender.tab.id;
  let entry = ports.get(id);
  if (!entry) {
    const port = chrome.runtime.connectNative('id.local.liris.bridge');
    entry = { port, pending: null }; ports.set(id, entry);
    port.onMessage.addListener(response => {
      if (response.command) chrome.tabs.sendMessage(id, { kind: 'liris-control', ...response }).catch(() => {});
    });
    port.onDisconnect.addListener(() => { void chrome.runtime.lastError; ports.delete(id); });
  }
  entry.port.postMessage({ ...message.packet, session: 'tab_' + id, origin: url.hostname === 'music.youtube.com' ? 'youtube-music' : 'youtube' });
  reply({ ok: true });
});
chrome.tabs.onRemoved.addListener(id => { ports.get(id)?.port.disconnect(); ports.delete(id); });
