# Native media defaultMuted reflection

HTML audio/video wrappers now expose `HTMLMediaElement.prototype.defaultMuted` through ordinary enumerable and configurable native getter/setter functions. The getter reads the actual `muted` content attribute’s presence. The setter applies WebIDL boolean conversion, then sets that attribute to an empty string or removes it.

Getter receiver branding precedes document replay. Setters check the receiver, apply ToBoolean, replay pending DOM changes, mutate the actual content attribute, then synchronize captured facade state. ToBoolean does not invoke author conversion hooks, including for Symbol, BigInt, objects or revoked proxies; an omitted setter argument converts to false. Existing exceptions from compact replay retain their JavaScript identity, and runtime/host close guards release the retained callback and DOM records.

A private media-only WeakMap records each parsed or script-created facade alongside its captured compact state. The native setter mirrors the actual DOM mutation through a retained synchronization callback using captured WeakMap, Reflect and property-definition intrinsics. It bypasses public attribute methods and the facade’s exposed state lookup. Subsequent unrelated dirty attribute snapshots therefore retain the native reflected write. Ordinary and SVG elements keep their own interfaces.

`defaultMuted` remains independent of runtime `muted`: changing the content attribute does not change effective volume, enqueue volumechange, initiate fetching or start playback. Existing model initialization and mute policy remain unchanged. This slice does not claim complete media initialization, autoplay policy or full HTMLElement parity.

The implementation calls the real DOM attribute mutation path, retaining its mutation records and custom-element callback queues. Synchronous customized-built-in CEReactions callback delivery remains open; the binding does not consume or discard those queues. General tampering with exposed compact compiler state also remains outside full interface parity.

Five focused cases in two files run in both GC modes. Three binding cases cover descriptor metadata and native function names/lengths, invalid and proxy receivers, truthy/falsy conversions, empty-value normalization, direct DOM presence, original replay exceptions, protected synchronization and close cleanup. Two owner cases cover parsed video and created audio, immediate facade and actual DOM reflection, content-attribute mutations, dirty-snapshot stability, poisoned public methods and globals, runtime-muted independence, zero extra fetches/events, execution-context balance and retained attribute-selector text painting.

The isolated source uses the committed feature HEAD/index plus the six captured branding overrides. Foreign rendering drafts and other uncommitted runtime work are excluded from focused test credit. Canonical preservation verifies the five complete browser/root files and the two media bootstrap gates in live `main.v`, while retaining snapshots of concurrent main content. Earlier helpers, validation sources, scratch, evidence and unrelated edits remain intact.

Prior preservation is inherited through authenticated predecessor containers covering 227,340 records. The current native SDK inputs are authenticated and exposed as regular hardlinks on the same RAM volume; this slice does not repeat a complete historical artifact-union walk.

The six paths are support code outside assigned DOM ownership. The broad baseline remains `056556523cd2de75a2918f2cdfc3eee22afc832f`; defaultMuted is fix 6, so broad regression suites, production builds and screenshot suites remain deferred at 6/10.

Implementation: `af34b569b12f50ceef47b77a68c14fa720aecce2`.
Evidence: `Build/audit-fixes/native-media-default-muted-host-evidence-v1.json` (SHA256 `e85d8247049581f71b2094c8783e8204a396b94bcdd31d8c780dd7bedba2cfe0`).
Inventory: `Build/audit-fixes/native-media-default-muted-host-inventory-scoped-v1.json` (SHA256 `a9b1f877e2ce5e5f72bd5069c8627fbe5725bb4e71cfd90461981b5fd68a8b72`).
Prior verification is inherited from authenticated containers covering 227,340 records; historical files are not rehashed. Broad baseline stays `056556523cd2de75a2918f2cdfc3eee22afc832f`; cadence is 6/10.
