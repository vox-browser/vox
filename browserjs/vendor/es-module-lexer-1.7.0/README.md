Pinned unmodified asm.js and Wasm distributions of es-module-lexer 1.7.0.

Source: https://github.com/guybedford/es-module-lexer/tree/1.7.0
Package: https://registry.npmjs.org/es-module-lexer/-/es-module-lexer-1.7.0.tgz

Package integrity: `sha512-jEQoCwk8hyb2AZziIOLhDqpm5+2ww5uIE6lkO/6jcOCusfk6LhMHpXXfBLXTZ7Ydyt0j4VoUQv6uGNYbdW+kBA==`
Wasm distribution SHA-256: `36dc42b0c379cc7d0911ffbc136844729fe3a529f89194ed672cc911d5357f46`

Vox embeds the lexer in a private host closure. The embedding removes export
declarations, suppresses the Wasm distribution's asynchronous eager initializer,
and calls its synchronous initializer lazily when specifier lexing is needed.
A private decoder supplies the fixed Wasm payload without global Buffer/atob
bindings. Native WebAssembly constructors/accessors are captured before author code can
replace them. The Wasm build reuses the asm build's strict quoted-string decoder
instead of eval, preserving its invalid-escape rejection. JSC still validates
and executes the original module syntax.

The private embedding can copy source UTF-16 through JavaScriptCore's native
string/typed-array APIs, followed by a captured typed-array setter into Wasm
memory. This avoids a JavaScript call and element write for every code unit.
The temporary array owns its storage; JSC's movable Wasm backing pointer is
never borrowed. NULs and lone surrogates are preserved. The original JavaScript
copy loop remains the fallback and the `VOX_RETAIN_JS_MODULE_LEXER_COPY=1`
control. Neither the author global nor the pinned distributions are changed.

The original asm.js build remains the control and the fallback when WebAssembly
is unavailable or initialization fails. Neither build needs Node or a network
fetch at runtime. JavaScriptCore retains parsing, module linking, live bindings,
cycles and execution; the lexer identifies URL specifiers for HTML import-map
resolution. Keyword-free scripts avoid initializing either lexer.
