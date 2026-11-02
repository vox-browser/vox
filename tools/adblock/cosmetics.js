// Native embedding of the full uBlock Origin 1.75.0 cosmetic and scriptlet engines.
import './platform.js';
import { createResources } from './resources.js';
import cosmeticEngine from '../../adblock/vendor/ublock/js/cosmetic-filtering.js';
import { ScriptletFilteringEngine } from '../../adblock/vendor/ublock/js/scriptlet-filtering-core.js';
import { redirectEngine } from '../../adblock/vendor/ublock/js/redirect-engine.js';
import { AstFilterParser, utils } from '../../adblock/vendor/ublock/js/static-filtering-parser.js';
import { CompiledListWriter, CompiledListReader } from '../../adblock/vendor/ublock/js/static-filtering-io.js';
import { hostnameFromURI, domainFromHostname } from '../../adblock/vendor/ublock/js/uri-utils.js';

const scriptletEngine = new ScriptletFilteringEngine();
const environment = ['chromium', 'ublock', 'user_stylesheet'];

export { redirectEngine };

function initializeResources() {
    const tables = createResources();
    redirectEngine.resources = tables.resources;
    redirectEngine.aliases = tables.aliases;
}

export function initializeCosmetics(lists) {
    initializeResources();
    cosmeticEngine.reset();
    scriptletEngine.reset();
    for (const list of lists) {
        const writer = new CompiledListWriter();
        const parser = new AstFilterParser({
            nativeCssHas: true,
            // Only the publisher's own uBlock lists may use trusted scriptlets.
            trustedSource: (list.name || list.key || '').startsWith('ublock-'),
            trustedTokens: new Set(),
        });
        const content = utils.preparser.prune(list.raw || list.content || '', environment);
        for (const line of content.split(/\r?\n/)) {
            if (!line.includes('#')) continue;
            parser.parse(line.trim());
            if (parser.hasError() || !parser.isExtendedFilter()) continue;
            if (parser.isScriptletFilter()) scriptletEngine.compile(parser, writer);
            else if (parser.isCosmeticFilter()) cosmeticEngine.compile(parser, writer);
        }
        parser.finish();
        const reader = new CompiledListReader(writer.toString());
        cosmeticEngine.fromCompiledContent(reader, {});
        scriptletEngine.fromCompiledContent(reader);
    }
    cosmeticEngine.freeze();
    scriptletEngine.freeze();
}

export function cosmeticSnapshot() {
    return { cosmetic: cosmeticEngine.toSelfie(), scriptlets: scriptletEngine.toSelfie() };
}

export function restoreCosmetics(snapshot) {
    initializeResources();
    cosmeticEngine.fromSelfie(snapshot.cosmetic);
    scriptletEngine.fromSelfie(snapshot.scriptlets);
}

// Use uBO's identical surveyor hash on IDs/classes present in the live document.
function hashToken(token) {
    const type = token.charCodeAt(0), text = token.slice(1), len = text.length;
    const step = (len + 7) >>> 3;
    let hash = ((type << 5) + type) ^ len;
    for (let i = 0; i < len; i += step) hash = ((hash << 5) + hash) ^ text.charCodeAt(i);
    return hash & 0xFFFFFF;
}

export function documentFilters(url, tokens = [], options = {}) {
    const hostname = hostnameFromURI(url);
    if (!/^https?:\/\//i.test(url) || !hostname) return { css: '', scriptlets: '', procedural: [], filters: [] };
    const request = { url, hostname, domain: domainFromHostname(hostname) || hostname };
    const specific = cosmeticEngine.retrieveSpecificSelectors(request, { ...options, dontInject: true });
    let css = specific.injectedCSS || '';
    if (!options.noGenericCosmeticFiltering) {
        const generic = cosmeticEngine.retrieveGenericSelectors({
            hashes: [...new Set(tokens.filter(t => t.length > 1).map(hashToken))],
            exceptions: specific.exceptionFilters,
        });
        if (generic?.injectedCSS) css += '\n' + generic.injectedCSS;
    }
    const scriptlets = scriptletEngine.retrieve(request);
    return {
        css,
        scriptlets: (scriptlets?.mainWorld || '') + (scriptlets?.isolatedWorld ? '\n(' + scriptlets.isolatedWorld + ')();' : ''),
        procedural: specific.proceduralFilters || [],
        filters: scriptlets?.filters || [],
    };
}

export function resolveRedirect(token, requestType) {
    // Empty responses preserve the initiating resource's MIME type.
    if (token === 'empty') {
        const mime = { script: 'text/javascript', stylesheet: 'text/css', main_frame: 'text/html', sub_frame: 'text/html' }[requestType] || 'text/plain';
        return `data:${mime},`;
    }
    return redirectEngine.tokenToURL({ type: requestType }, token.replace(/^%/, ''), true) || '';
}
