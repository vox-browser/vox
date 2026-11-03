import vm from 'node:vm';
import { transformSync } from 'esbuild';

// Deferred assets run through classic-script eval in JavaScriptCore. Preserve
// existing bundled bytes, but lower standalone ES modules before embedding.
export function classicScript(source) {
    try {
        new vm.Script(source);
        return source;
    } catch (error) {
        if (!(error instanceof SyntaxError)) throw error;
    }
    const { code } = transformSync(source, {
        format: 'iife', target: 'safari16.4', minify: true, legalComments: 'eof',
    });
    new vm.Script(code);
    return code;
}
