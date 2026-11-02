// Follow full uBO's retrieveContentScriptParameters policy for the actual
// top-level tab. Querying the cosmetic engines without it bypasses $ghide and
// $shide exceptions and invents filters that the extension never injects.
// Self-contained so the same function runs in the extension's CDP context.
export function collectOracleCosmetics(pageStores, cosmeticEngine, scriptletEngine, request, tokens) {
    const stores = [...pageStores.values()].filter(store => store.rawURL === request.url);
    if (stores.length !== 1 || stores[0].getNetFilteringSwitch() !== true) {
        throw new Error('Cosmetic oracle requires one enabled full-uBO tab for the document');
    }
    const store = stores[0];
    const noGenericCosmeticFiltering = store.shouldApplyGenericCosmeticFilters(0) === false;
    const noSpecificCosmeticFiltering = store.shouldApplySpecificCosmeticFilters(0) === false;
    const details = {...request, tabId:store.tabId, frameId:0};
    cosmeticEngine.removeFromSelectorCache(request.hostname, 'cosmetic');
    const specific = cosmeticEngine.retrieveSpecificSelectors(details, {
        dontInject:true, noGenericCosmeticFiltering, noSpecificCosmeticFiltering,
    });
    let css = specific.injectedCSS || '';
    if (!noGenericCosmeticFiltering) {
        const hashToken = token => {
            const type=token.charCodeAt(0),text=token.slice(1),len=text.length,step=(len+7)>>>3;
            let hash=((type<<5)+type)^len;
            for(let i=0;i<len;i+=step) hash=((hash<<5)+hash)^text.charCodeAt(i);
            return hash&0xFFFFFF;
        };
        const generic = cosmeticEngine.retrieveGenericSelectors({...details,
            hashes:[...new Set(tokens.filter(token=>token.length>1).map(hashToken))],
            exceptions:specific.exceptionFilters});
        if (generic?.injectedCSS) css += '\n' + generic.injectedCSS;
    }
    return {css, procedural:specific.proceduralFilters||[],
        filters:scriptletEngine.retrieve(details)?.filters||[],
        policy:{tab_id:store.tabId,frame_id:0,
            generic_enabled:!noGenericCosmeticFiltering,specific_enabled:!noSpecificCosmeticFiltering}};
}
