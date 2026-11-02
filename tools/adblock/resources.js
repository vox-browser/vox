import redirectableResources from '../../adblock/vendor/ublock/js/redirect-resources.js';
import { builtinScriptlets } from '../../adblock/vendor/ublock/js/resources/scriptlets.js';
import resourceData from '../../adblock/extended/redirect-resources.json';

export function createResources() {
    const resources = new Map(), aliases = new Map();
    for (const scriptlet of builtinScriptlets) {
        const name = scriptlet.name;
        const data = scriptlet.fn.toString();
        resources.set(name, {
            ...scriptlet,
            mime: name.endsWith('.fn') ? 'fn/javascript' : 'text/javascript',
            data,
            dependencies: scriptlet.dependencies || [],
            toContent: () => data,
        });
        for (const alias of scriptlet.aliases || []) aliases.set(alias, name);
    }
    for (const [name, details] of redirectableResources) {
        const resource = resourceData[name];
        if (resource) resources.set(name, {
            mime: resource.mime, data: resource.data,
            dependencies: [],
            toContent: () => resource.text || '',
            toURL: fctx => name === 'empty'
                ? `data:${({ script: 'text/javascript', stylesheet: 'text/css', main_frame: 'text/html', sub_frame: 'text/html' })[fctx.type] || 'text/plain'},`
                : resource.data,
        });
        for (const alias of (Array.isArray(details.alias) ? details.alias : details.alias ? [details.alias] : [])) {
            aliases.set(alias, name);
        }
    }
    return { resources, aliases };
}

// Page scriptlets consume source text. Preserve its bytes without parsing every
// function in the isolated filter VM on each launch.
export function snapshotResources() {
    const {resources,aliases} = createResources();
    return { entries: new Map([...resources].map(([name,entry]) => {
        const {fn,toContent,toURL,...metadata} = entry;
        return [name,{...metadata,content:toContent(),redirect:typeof toURL==='function'}];
    })), aliases };
}
