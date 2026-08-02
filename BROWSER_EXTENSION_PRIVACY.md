# Delore Browser Bridge privacy

Delore Browser Bridge reads the titles, URLs, favicons, active state and window
identifiers of open browser tabs so they can be displayed and routed inside the
locally installed Delore application.

The extension sends this information only to `127.0.0.1`, where Delore listens
for the browser connection. Delore Browser Bridge does not send browsing data to
Delore's developers, an analytics service or any other remote server.

The extension stores only a randomly generated browser instance identifier, a
local pairing token and the latest connection status in browser local storage.
Removing the extension removes this browser-local data. Delore routing settings
can be removed from Delore itself.

The extension does not inject scripts into websites, modify page contents,
collect form contents, read passwords or sell user data.

Questions and source code:
https://github.com/DeLorean-bot/Delore
