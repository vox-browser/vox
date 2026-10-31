Pinned unmodified asm.js distribution of es-module-lexer 1.7.0.

Source: https://github.com/guybedford/es-module-lexer/tree/1.7.0
Package: https://registry.npmjs.org/es-module-lexer/-/es-module-lexer-1.7.0.tgz

Vox embeds this lexer in a private host closure. Only its `export` declaration
is removed when embedding. JavaScriptCore still parses, links, and executes
the original module syntax; the lexer identifies URL specifiers for HTML
import-map resolution. No runtime WebAssembly or Node dependency is required.
