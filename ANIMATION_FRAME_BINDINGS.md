# Owning Window animation-frame bindings

Upstream reference: Ladybird `963d46a829f3e1b79f44dba9d02afb70654300fa`,
`Libraries/LibWeb/HTML/{AnimationFrameProvider.idl,AnimationFrameCallbackDriver.cpp,Window.cpp}`,
`HTML/EventLoop/EventLoop.cpp`, `DOM/Document.cpp`, and
`Services/WebContent/PageClient.cpp`.

The compact browser and inline-document bridge now expose
`requestAnimationFrame()` and `cancelAnimationFrame()` through
`browserjs.AnimationFrameHost`. They use the actual owning `WindowModel` driver;
the former immediate JavaScript functions are removed. The binding retains each
real engine callback while pending or executing and releases it after execution,
pending cancellation, or owner-runtime shutdown. Closing the binding cancels
only its own handles, preserving callbacks registered by other source callers.

`AnimationFrameProvider.idl` supplies the required callable argument, required
unsigned-long cancellation argument, method lengths, and owning Window receiver.
Conversion preserves original author exceptions and the unsigned-long modulo
rules. `Runtime.webidl_callback` performs the source synchronous WebIDL call with
an undefined receiver, the actual relevant/incumbent realm preparation and
cleanup, and the real engine values. Callback return values are discarded;
Promise Resolve and `then` access do not occur. A thrown value reaches the
owning scripting realm's existing source console-exception record unchanged.
Other callbacks in that frame continue.

The driver preserves pinned upstream behavior: it moves the pending ordered map
into an executing snapshot. Newly requested callbacks wait for another frame.
Cancellation removes entries in the pending map; a callback already in that
executing snapshot still runs. This retains the upstream Window implementation's
documented approximation of the specification rather than changing its logic.

Native navigation attaches its actual navigable as the Page's local rendering
root, retaining that root identity across replacement documents. This lets the
source rendering task consume PageClient display grants.
The native display callback grants an opportunity to the actual PageClient and
calls the source HTML event loop's `rendering_opportunity()`. The event loop
queues the rendering task and supplies document eligibility, hidden/render-blocked
and view-transition suppression checks, rendering stage order, and document-relative
coarsened timestamps. Display timestamps now use upstream's
`max(previous, min(frame_time, shared_now))` clamp. The compact replay callback
reflects author mutations into the live DOM before the rendering task's layout
stage; the existing asynchronous replay path refreshes the native app's retained
paint state.

Compact navigation records each locally produced `LoadedPage` response's actual
monotonic creation time. Following `Document.cpp`'s non-Fetch response fallback,
it installs the coarsened navigation start time before HTML parsing. Window time
origin continues to read that same associated Document record, and the compact
CSS animation adapter uses the same origin. This does not add fabricated Fetch
timing data to the compact HTTP loader.

Focused coverage includes real rendering-task ownership, owning/incumbent
execution contexts, callback receiver and ignored thenable return, nested frame
ordering, pending and executing cancellation, hidden/suppressed/render-blocked
and inactive-document gates, actual thrown-value identity, unsigned-long and
receiver conversions, engine-root release, shutdown, DOM replay before layout,
and navigation response timing. Existing load/selection/style bridge fixtures
now deliver real source rendering opportunities.

Remaining embedding boundaries are explicit: the compact macOS shell supplies
local native display callbacks instead of WebContent compositor IPC/watchdog
scheduling; the console adapter records source exceptions without a complete
upstream console/debugger frontend. This slice exposes Window animation-frame
bindings, not a new compact DedicatedWorker global or its animation-frame API.
Other existing standalone compact APIs remain separately tracked translation
work.
