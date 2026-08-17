# LibWeb V translation

This repository at `~/code/libweb_v` is the canonical workspace for the V
translation of Ladybird's LibWeb. The upstream C++ reference is
`~/code/3rd/ladybird/Libraries/LibWeb`.

All translated V implementation code, tests, generated translation assets, and
translation-specific documentation belong in this repository. See
[`PORT_STATUS.md`](PORT_STATUS.md) for the module inventory and LOC table, and
[`ROOT_SUPPORT.md`](ROOT_SUPPORT.md) for the root support-file mapping.

Build the V-native translated-engine viewer with:

```sh
./build_ladybird.sh
open Build/v/Ladybird.app
```

The application provides a native single-tab browser chrome with back/forward,
reload, home, an editable address/search field, link navigation, loading and
console status, and scrolling. HTTP(S), local files, external stylesheets, and
classic scripts feed the translated HTML, DOM, CSS, Layout, hit-testing,
history, and paint-command pipeline. On macOS, JavaScriptCore supplies actual
ECMAScript evaluation at the translated Bindings host boundary; common
`document`, element mutation, location, events, timers, and console operations
are bridged back into the translated DOM before reflow.

Pass a URL, local HTML path, or raw HTML to the bundle executable to open it. A
small non-windowed build/startup check is available as:

```sh
Build/v/Ladybird.app/Contents/MacOS/Ladybird --headless-smoke
```

This bundle is distinct from `~/code/3rd/ladybird/Build/.../Ladybird.app`, which
is the upstream C++ application. The V-native application does not yet provide
the full generated Web-IDL JavaScript surface, multi-process isolation, tabs,
downloads, media/image painting, or persistent browser profiles.

Run the full translation test suite with:

```sh
v test .
```
