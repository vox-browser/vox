// Reproduce the version-pinned basic ChatGPT policy from reviewed originals.
import fs from 'node:fs/promises';
import crypto from 'node:crypto';
import { gunzipSync } from 'node:zlib';
import { createRequire } from 'node:module';
const { parse } = createRequire(new URL('../tools/adblock/package.json', import.meta.url))('acorn');

const fixtureURL = new URL('../tools/adblock/fixtures/chatgpt-basic-20261106.json.gz', import.meta.url);
const archiveURL = new URL('../Tests/Browser/Brave/archives/chatgpt-home-20261104-v2/archive/', import.meta.url);
const base = 'https://chatgpt.com/unauth-mweb/assets/';
const escape = value => value.replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replaceAll('/', '\\/');
const absoluteImports = source => source.replace(/from(["'])\.\//g, 'from$1' + base);
const noop = name => name === 'default' ? 'export default function(){}' : `export function ${name}(){}`;

export async function buildBasicResources() {
    const fixture = JSON.parse(gunzipSync(await fs.readFile(fixtureURL)));
    const resources = new Map(), reviewed = [], filters = [];
    for (const {version, modules} of fixture.releases) {
        async function original(kind) {
            const entry = modules[kind];
            const source = entry.source ?? await fs.readFile(new URL('bodies/' + entry.sha256, archiveURL), 'utf8');
            if (Buffer.byteLength(source) !== entry.bytes ||
                crypto.createHash('sha256').update(source).digest('hex') !== entry.sha256) {
                throw new Error('Changed reviewed ChatGPT source: ' + entry.url);
            }
            return {...entry, source};
        }
        for (const kind of Object.keys(modules)) {
            const entry = await original(kind);
            if (kind === 'locale' || reviewed.some(record => record.url === entry.url)) continue;
            const {source, url} = entry;
            const ast = parse(source, {sourceType:'module', ecmaVersion:'latest'});
            const exports = ast.body.filter(node => node.type === 'ExportNamedDeclaration')
                .flatMap(node => node.specifiers.map(specifier => specifier.exported.name));
            let code;
            // These optional surfaces have no role in the native text composer,
            // submission, streaming or transcript. Keep their linking contracts.
            if (['beacon', 'trending', 'product', 'login'].includes(kind)) {
                code = exports.map(noop).join('\n');
            } else if (kind === 'sheet') {
                code = 'export function t(){} export function n(){} export function r(){} ' +
                    'export async function i(){return {dispose(){}}} ' +
                    'export const a={BottomSheet:t,BottomSheetExternalContent:n,BottomSheetIconButton:r,BottomSheetFrame:t,mountBottomSheet:i};';
            } else if (kind === 'tracking') {
                // Acknowledge business batches so callers do not retry telemetry.
                // The URL sanitizer returns no value; no unsanitized URL escapes.
                code = ['a', 'i', 'n', 's', 't'].map(noop).join('\n') +
                    '\nexport function o(){return false} export function r(){return true}';
            } else if (kind === 'cta') {
                code = 'export function n(){} export function r(){return ()=>{}} export function t(value){return value}';
            } else if (kind === 'onetap') {
                code = 'export function installOctaneDesktopOneTap(){return ()=>{}}';
            } else if (kind === 'install') {
                code = '';
            } else if (kind === 'client') {
                // The original cache shares a full locale object across scopes.
                // Separate scope keys let the compact startup pack coexist with
                // the site's full packs, loaded normally by deferred features.
                const key = '`locales/${e}`';
                if (source.split(key).length !== 2) throw new Error('Changed locale cache key');
                code = absoluteImports(source.replace(key, '`locales/${e}/${t}`'))
                    .replaceAll('import.meta.url', JSON.stringify(url));
            } else if (kind === 'analytics') {
                const cuts = [];
                for (const node of ast.body) {
                    if (node.type === 'ImportDeclaration' && node.source.value.endsWith('/' + modules.tracking.url.split('/').pop())) {
                        cuts.push([node.start, node.end, '']);
                    }
                    if (node.type === 'ExpressionStatement' && source.slice(node.start, node.end) === 'typeof document<"u"&&p();') {
                        cuts.push([node.start, node.end, '']);
                    }
                    if (node.type === 'VariableDeclaration') for (const declaration of node.declarations) {
                        if (declaration.id.name === 'f') cuts.push([declaration.init.start, declaration.init.end, '{}']);
                        if (declaration.id.name === 'k') cuts.push([declaration.init.start, declaration.init.end, 'i(()=>{})']);
                    }
                }
                if (cuts.length !== 4) throw new Error('Changed analytics facade');
                code = source;
                for (const [start, end, replacement] of cuts.sort((a,b) => b[0] - a[0])) {
                    code = code.slice(0, start) + replacement + code.slice(end);
                }
                code = absoluteImports(code);
            } else if (kind === 'startup') {
                const locale = await original('locale');
                // This reviewed locale module is declarations only, with no imports.
                const packs = (await import('data:text/javascript;base64,' + Buffer.from(locale.source).toString('base64'))).default;
                const pack = packs['app.startup'];
                const digest = source.match(/catalogDigest:"([a-f\d]+)"/)[1];
                code = `const packs=${JSON.stringify({'app.startup':pack})};let fallback;
export const kind="locale";
export default async function(locale,flag=false,override){
if(locale==="en-US"&&!override)return packs;
fallback??=await import(${JSON.stringify(url + '?vox-full=1')});
return fallback.default(locale,flag,override)}
export function getScopePack(value,scope,locale){
if(scope==="app.startup"&&locale==="en-US"){
const p=value[scope];
if(!p||p.packDigest!==${JSON.stringify(pack.packDigest)}||p.locale!==locale||p.scope!==scope)throw Error("Stale i18n pack for "+scope+"/"+locale);
return {catalogDigest:${JSON.stringify(digest)},locale:p.locale,messages:p.messages,scope:p.scope}}
if(!fallback)throw Error("I18n locale was not loaded");return fallback.getScopePack(value,scope,locale)}\n`;
            } else throw new Error('Unknown reviewed module kind: ' + kind);
            const resource = 'vox-basic-' + url.split('/').pop();
            const query = kind === 'startup' ? '(?:\\?(?!vox-full=1(?:&|$))[^#]*)?' : '(?:\\?[^#]*)?';
            filters.push(`/^${escape(url)}${query}$/$script,match-case,domain=chatgpt.com,redirect=${resource}`);
            resources.set(resource, code);
            reviewed.push({...entry, kind, version, resource});
        }
    }
    return {filters:filters.join('\n'), resources, reviewed};
}

export async function writeBasicResources() {
    const {filters, resources} = await buildBasicResources();
    const source = '// Generated by build_chatgpt_basic.mjs; review pinned originals before refreshing.\n' +
        'export const basicSiteFilters = ' + JSON.stringify('\n' + filters + '\n') + ';\n' +
        'export const basicSiteResources = new Map(' + JSON.stringify([...resources], null, 2) + ');\n';
    await fs.writeFile(new URL('./chatgpt_basic_resources.js', import.meta.url), source);
    console.log('Generated basic ChatGPT resources: ' + resources.size);
}
