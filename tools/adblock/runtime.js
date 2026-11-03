import './polyfills.js';
import './platform.js';
import * as sfp from '../../adblock/vendor/ublock/js/static-filtering-parser.js';
import { CompiledListReader, CompiledListWriter } from '../../adblock/vendor/ublock/js/static-filtering-io.js';
import { FilteringContext } from '../../adblock/vendor/ublock/js/filtering-context.js';
import { LineIterator } from '../../adblock/vendor/ublock/js/text-utils.js';
import publicSuffixList from '../../adblock/vendor/ublock/lib/publicsuffixlist/publicsuffixlist.js';
import punycode from '../../adblock/vendor/ublock/lib/punycode.js';
import snfe from '../../adblock/vendor/ublock/js/static-net-filtering.js';
import { initializeCosmetics, documentFilters, redirectEngine, cosmeticSnapshot, restoreCosmetics } from './cosmetics.js';
import defaultData from './generated-defaults.js';
import * as serializer from '../../adblock/vendor/ublock/js/s14e-serializer.js';
import { checkResponseHeaders } from './response_headers.js';
import { snapshotResources } from './resources.js';

const environment = ['ublock', 'chromium', 'user_stylesheet'];
globalThis.voxAdblockLoadRegexAnalyzer = () => {
    if (!globalThis.Regex) (0, eval)(defaultData.regexSource());
    globalThis.voxAdblockRegexAnalyzerLoaded = true;
    return globalThis.Regex.Analyzer;
};
globalThis.voxAdblockLoadParser = () => {
    if (!globalThis.voxAdblockParser) {
        globalThis.voxAdblockLoadRegexAnalyzer();
        (0, eval)(defaultData.parserSource());
    }
    return globalThis.voxAdblockParser;
};
globalThis.voxAdblockLoadResources = () => {
    return defaultData.resources();
};
globalThis.voxAdblockLoadBuiltinScriptlets = () => {
    if (!globalThis.voxAdblockBuiltinScriptlets) (0, eval)(defaultData.builtinScriptletsSource());
    return globalThis.voxAdblockBuiltinScriptlets;
};
globalThis.voxAdblockResourceSnapshot = () => snapshotResources();
const fctx = new FilteringContext();
let activeListCount = 0;
function compileNetwork(raw, name) {
    const compiler = snfe.createCompiler();
    const writer = new CompiledListWriter();
    writer.properties.set('name', name);
    // Official uBO lists may contain trusted options; custom filters are also
    // user-owned, matching the full extension's trusted user filter behavior.
    writer.properties.set('trustedSource', true);
    const parser = new sfp.AstFilterParser({ maxTokenLength: snfe.MAX_TOKEN_LENGTH, trustedSource: true });
    const lines = new LineIterator(raw);
    compiler.start(writer);
    while (!lines.eot()) {
        let line = lines.next();
        while (line.endsWith(' \\') && lines.peek(4) === '    ') {
            line = line.slice(0, -2).trim() + lines.next().trim();
        }
        parser.parse(line);
        if (parser.isNetworkFilter()) compiler.compile(parser, writer);
    }
    compiler.finish(writer);
    return writer.toString();
}

globalThis.voxAdblockInitialize = customFilters => {
    if (customFilters === undefined && defaultData.restore) {
        const snapshot = defaultData.restore();
        if (!publicSuffixList.fromSelfie(snapshot.public_suffixes)) {
            throw new Error('Invalid bundled public suffix snapshot');
        }
        if (!snapshot || snfe.fromSelfie(snapshot.network) !== true) {
            throw new Error('Invalid bundled uBlock Origin engine snapshot');
        }
        restoreCosmetics(snapshot.cosmetics);
        activeListCount = snapshot.list_count;
        return JSON.stringify({ filter_count: snfe.getFilterCount(), list_count: activeListCount });
    }
    publicSuffixList.parse(defaultData.publicSuffixText(), punycode.toASCII);
    const lists = customFilters === undefined ? defaultData.lists : [{ name: 'user-filters', raw: customFilters }];
    const prepared = lists.map(list => ({ ...list, raw: sfp.utils.preparser.prune(list.raw, environment) }));
    snfe.reset();
    const networkCompiled = prepared.map(list => compileNetwork(list.raw, list.name));
    for (const compiled of networkCompiled) snfe.fromCompiled(new CompiledListReader(compiled));
    snfe.freeze();
    snfe.optimize(0);
    initializeCosmetics(prepared);
    activeListCount = lists.length;
    return JSON.stringify({ filter_count: snfe.getFilterCount(), list_count: lists.length });
};

globalThis.voxAdblockSnapshot = () => serializer.serialize({ list_count: activeListCount, network: snfe.toSelfie(), cosmetics: cosmeticSnapshot(), public_suffixes: publicSuffixList.toSelfie() }, { compress: false });
globalThis.voxAdblockCheckResponse = (details, headers) => JSON.stringify(checkResponseHeaders(snfe, fctx, details, headers));

globalThis.voxAdblockCheck = details => {
    const type = details.request_type === 'fetch' ? 'xmlhttprequest' : details.request_type || 'other';
    fctx.setURL(details.url).setDocOriginFromURL(details.source_url || details.url)
        .setTabOriginFromURL(details.source_url || details.url).setType(type).setMethod(details.method || 'GET');
    fctx.redirectURL = undefined;
    const result = snfe.matchRequest(fctx);
    const log = result === 0 ? undefined : snfe.toLogData();
    const decision = { blocked: result === 1, exception: result === 2, rule: log?.raw || '', redirect_url: '', error: '' };
    if (result === 1) {
        snfe.redirectRequest(redirectEngine, fctx);
    } else {
        snfe.transformURL(fctx);
        if (snfe.hasQuery(fctx)) snfe.filterQuery(fctx);
    }
    if (fctx.redirectURL !== undefined && fctx.redirectURL !== details.url) decision.redirect_url = fctx.redirectURL;
    return JSON.stringify(decision);
};
globalThis.voxDocumentFilters = (url, tokens = []) => {
    const options = {};
    for (const type of ['generichide', 'specifichide']) {
        fctx.setURL(url).setDocOriginFromURL(url).setTabOriginFromURL(url).setType(type).setMethod('');
        if (snfe.matchRequest(fctx, 0b11) === 2) {
            options[type === 'generichide' ? 'noGenericCosmeticFiltering' : 'noSpecificCosmeticFiltering'] = true;
        }
    }
    return documentFilters(url, tokens, options);
};
