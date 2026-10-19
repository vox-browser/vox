# Native browser proxy routing

This is one completed runtime fix after the native-media checkpoint
`78e6e89f`. Browser navigation and resource requests now select a configured
proxy at every redirect hop. `VOX_PROXY` overrides per-scheme and ALL proxy
environment variables; an empty override disables ambient proxies. Host and
domain exclusions honor NO_PROXY. Invalid and failed proxies never trigger
a direct retry.

The repository-owned HTTP compatibility staging preserves request CA and
hostname verification inside SOCKS5 and HTTP CONNECT tunnels. It also sends
origin-form request targets inside those tunnels. Destination names pass to
SOCKS5 without local DNS resolution. The current proxied path uses HTTP/1.1;
the direct connection pool retains HTTP/2 negotiation.

Focused checks: `browsernet/proxy_test.v` passes with Boehm and `-gc none`
using `Build/v/modules` in the V module path. Its local SOCKS server covers
an unresolvable synthetic hostname, redirects, binary bodies, trusted TLS,
untrusted CAs, wrong certificate hostnames, and connection refusal without
direct fallback. `browsernet/http_test.v` also passes with the staged module.
Cookie-import, exact-pixel-checker and Brave-capture Python tests pass.

Brave's isolated reference capture accepts the same imported Netscape cookie
jar and SOCKS5 endpoint. On 2026-10-17 the endpoint served example.com, while
Reddit returned its network-security block with the imported account cookies.
See [Reddit reproduction and scope](../OLD_REDDIT_BRAVE_PARITY.md).
