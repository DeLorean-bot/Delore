const status = document.querySelector('#status');

document.querySelector('#sync').addEventListener('click', async () => {
  status.textContent = 'Connecting...';
  const result = await chrome.runtime.sendMessage({type: 'sync'});
  status.textContent = result?.ok
    ? 'Connected - tabs are syncing'
    : `Open Delore - ${result?.reason || 'not available'}`;
});

chrome.runtime.sendMessage({type: 'status'}).then(value => {
  if (!value?.pairingToken) status.textContent = 'Open Delore to connect';
  else if (value.lastError) status.textContent = `Connected - ${value.lastError}`;
  else status.textContent = 'Connected';
});
