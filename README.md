## Vox Browser

https://vox-browser.org

[Windows build instructions](docs/WINDOWS.md)

<img width="2078" height="1628" alt="image" src="https://github.com/user-attachments/assets/ed3d6776-78dd-4903-b716-a95cd5845cab" />

Vox compiles in 2 seconds on M5 Max with `v .`!

With the native dependencies installed, update UI2 and compile directly:

```sh
v up ui2
v -b fastc -enable-globals .
```

For a first install, use `v install https://github.com/vlang/ui2`.
UI2 must include its [embedding API](https://github.com/vlang/ui2/blob/master/docs/embedding.md).
The production build also checks this dependency version.

HTML/CSS - pure V, rendering via the V graphics module (DirectX 11, Metal, OpenGL, FreeType/stb_truetype).

GUI - V UI2

JS - JavaScriptCore/V8/Vox JS engine (still WIP)

### Goals

The goal is to develop a free, clean, fast to compile (a couple of seconds), easily embeddable (like Electron), efficient and low memory (like Opera's old Presto) browser engine.

Full pixel parity with Chrome.

Today's web is dominated by the Chromium engine. It's slow to compile (5 hours on top tier 2026 desktop hardware), hard to develop because of the huge and complicated C++ code base, uses a huge amount of resources.

Firefox, the last alternative to Chromium, has unfortunately strayed away from its initial focus on privacy (it has huge amounts of telemetry and questionable partnerships), it's not embeddable at all, is even harder to build and develop than Chromium due to an older code base, has worse performance and battery usage.

There's a clear room for a new fresh alternative. Having more browsers is healthier for the open web.

Developing a browser is a very difficult task because of the ever increasing complexity of the web. Companies like Opera and Microsoft gave up developing their own engines and switched to Chromium. However it's not impossible. For example, a new proprietary browser Flow now successfully works with Gmail, one of the most complicated web apps. The NetSurf browser works quite well with websites that don't rely on JavaScript for rendering.

The graphics/text rendering is handled completely by V's builtin libraries, and cross platform UI is handled by V UI2.

With the V language which focuses on simple and maintainable code with fast compilation time, developing a browser will be a much easier task.  

Initially we started with an implementation from scratch, but decided to use [Ladybird](https://ladybird.org/) as the foundation. In March 2026, we adopted an older version of Ladybird's C++ codebase, translated it into V, and have heavily modified and extended it since.


### Existing features
- Built-in ad blocking (using uBlock Origin lists).
- Built-in cookie banner blocking


### Planned features

- Focus on privacy and security. Complete lack of telemetry.
- Optional Vim-like keyboard control for working without mouse (similar to Chrome's Vimium plugin).
- Vertical tabs option (similar to Firefox's old Tree Style Tab extension).
- Mouse gestures (like in Opera).

### Acknowledgements

Vox builds on the work of Andreas Kling and the Ladybird and SerenityOS contributors. We thank them for the browser engine and libraries that made this translation possible.

Ladybird-derived code retains its BSD 2-Clause license and original copyright notices. See [third-party notices](THIRD_PARTY_NOTICES.md) for the full Ladybird license and notices for other bundled components.

### License

Copyright (c) 2026 Alexander Medvednikov.

Except where otherwise noted, Vox is licensed under the [GNU General Public License, version 2 or any later version](LICENSE) (`GPL-2.0-or-later`). The bundled uBlock Origin integration requires GPL version 3 or later for the combined distribution; see [third-party notices](THIRD_PARTY_NOTICES.md).

