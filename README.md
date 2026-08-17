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

The application parses HTML and drives the translated DOM, CSS, Layout, and
paint-command pipeline in a native window. Pass a local HTML path to the bundle
executable to render that file. A small non-windowed build/startup check is
available as:

```sh
Build/v/Ladybird.app/Contents/MacOS/Ladybird --headless-smoke
```

This bundle is distinct from `~/code/3rd/ladybird/Build/.../Ladybird.app`, which
is the upstream C++ application. Network navigation, JavaScript execution, and
the complete browser chrome are not yet wired into the V-native viewer.

Run the full translation test suite with:

```sh
v test .
```
