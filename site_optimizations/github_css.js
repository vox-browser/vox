// Rspack's short chunk CSS names duplicate named entry sheets in GitHub's SSR.
// Reuse only an already loaded, enabled sheet from a reviewed matching pair.
export function installGithubStylesheetAliases(runtime, document, aliases, onReuse) {
    if (typeof runtime?.k !== 'function') return false;
    const original = runtime.k;
    runtime.k = function (chunk) {
        const filename = original.apply(this, arguments);
        const alias = Object.hasOwn(aliases, chunk) ? aliases[chunk] : null;
        if (!alias || filename !== alias.chunk) return filename;
        try {
            const links = document.getElementsByTagName('link');
            for (let index = 0; index < links.length; index++) {
                const link = links[index];
                if (link.rel !== 'stylesheet' || link.href !== alias.url || link.disabled ||
                    link.hasAttribute('data-rspack-loading') ||
                    !['', 'all'].includes(link.media)) continue;
                const sheet = link.sheet;
                if (!sheet || sheet.disabled || !['', 'all'].includes(sheet.media?.mediaText)) continue;
                onReuse?.(chunk);
                return alias.filename;
            }
        } catch {
            // An unsupported CSSOM surface keeps the original loader path.
        }
        return filename;
    };
    return true;
}
