const ENDPOINT = 'http://127.0.0.1:47831/tabs';
const PAIR_ENDPOINT = 'http://127.0.0.1:47831/pair';
let timer;

async function identity() {
  const stored = await chrome.storage.local.get(['instanceId']);
  if (stored.instanceId) return stored.instanceId;
  const instanceId = crypto.randomUUID();
  await chrome.storage.local.set({instanceId});
  return instanceId;
}

async function pairingToken() {
  const stored = await chrome.storage.local.get(['pairingToken']);
  if (stored.pairingToken) return stored.pairingToken;
  const response = await fetch(PAIR_ENDPOINT, {cache: 'no-store'});
  if (!response.ok) throw new Error(`Pairing failed: HTTP ${response.status}`);
  const data = await response.json();
  if (!data.token) throw new Error('Pairing failed: Delore returned no token');
  await chrome.storage.local.set({pairingToken: data.token});
  return data.token;
}

async function syncTabs(retryPairing = true) {
  try {
    const token = await pairingToken();
    const tabs = await chrome.tabs.query({});
    const response = await fetch(ENDPOINT, {
      method: 'POST',
      headers: {'Content-Type': 'application/json', 'X-Delore-Token': token},
      body: JSON.stringify({
        browser: 'Firefox', instanceId: await identity(),
        tabs: tabs.map(tab => ({id: tab.id, windowId: tab.windowId, title: tab.title || '', url: tab.url || '', favIconUrl: tab.favIconUrl || '', active: Boolean(tab.active)}))
      })
    });
    if ((response.status === 401 || response.status === 403) && retryPairing) {
      await chrome.storage.local.remove('pairingToken');
      return syncTabs(false);
    }
    const ok = response.ok;
    await chrome.storage.local.set({lastSync: Date.now(), lastError: ok ? '' : `HTTP ${response.status}`});
    return {ok, reason: ok ? '' : `HTTP ${response.status}`};
  } catch (error) {
    await chrome.storage.local.set({lastError: String(error)});
    return {ok: false, reason: String(error)};
  }
}

function scheduleSync() { clearTimeout(timer); timer = setTimeout(syncTabs, 180); }
chrome.tabs.onCreated.addListener(scheduleSync);
chrome.tabs.onUpdated.addListener(scheduleSync);
chrome.tabs.onRemoved.addListener(scheduleSync);
chrome.tabs.onActivated.addListener(scheduleSync);
chrome.tabs.onMoved.addListener(scheduleSync);
chrome.windows.onFocusChanged.addListener(scheduleSync);
chrome.runtime.onStartup.addListener(syncTabs);
chrome.runtime.onInstalled.addListener(() => { chrome.alarms.create('delore-heartbeat', {periodInMinutes: 0.5}); syncTabs(); });
chrome.alarms.onAlarm.addListener(alarm => { if (alarm.name === 'delore-heartbeat') syncTabs(); });
chrome.runtime.onMessage.addListener((message, _, sendResponse) => {
  if (message?.type === 'status') { chrome.storage.local.get(['pairingToken', 'lastSync', 'lastError']).then(sendResponse); return true; }
  if (message?.type === 'sync') { syncTabs().then(sendResponse); return true; }
});

// An installed extension can wake after Delore (or after its pairing token was
// regenerated) without receiving onStartup/onInstalled again. Always restore
// the heartbeat and attempt one immediate self-healing sync.
chrome.alarms.create('delore-heartbeat', {periodInMinutes: 0.5});
syncTabs();
