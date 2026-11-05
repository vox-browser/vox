import fs from 'node:fs/promises';
import path from 'node:path';

// Cleanup can fail after the actual comparison error. Retain the original
// failure before closing the browser so its cause survives either outcome.
export async function recordOracleFailure(output, error) {
    console.error('Oracle comparison failed:', error?.stack || String(error));
    const file = path.resolve(output) + '.failure.json';
    try {
        await fs.mkdir(path.dirname(file), {recursive:true});
        await fs.writeFile(file, JSON.stringify({status:'failed',
            error:{name:error?.name || 'Error', message:error?.message || String(error),
                stack:error?.stack || null}}, null, 2) + '\n');
    } catch (writeError) {
        // A receipt failure must not replace the comparison's exception.
        console.error('Cannot retain oracle failure:', writeError);
    }
}
