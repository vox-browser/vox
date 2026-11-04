// Self-contained functions also executed inside full uBO's background context.
export async function installOracleLists(ublock,assets,lists) {
    ublock.userSettings.autoUpdate=false;
    ublock.saveUserSettings();
    await ublock.scheduleAssetUpdater();
    assets.updateStop();
    await ublock.saveUserFilters('');
    await ublock.saveSelectedFilterLists(lists.map(list=>list.name));
    for(const list of lists) await assets.put(list.name,list.content);
    await assets.remove(/^compiled\//);
    await ublock.loadFilterLists();
    return ublock.selectedFilterLists;
}

export async function oracleAssetIdentities(assets,entries) {
    const identities=[];
    for(const entry of entries) {
        const result=await assets.get(entry.name);
        if(result.error || typeof result.content!=='string') throw Error('Missing oracle list: '+entry.name);
        const hash=await crypto.subtle.digest('SHA-256',new TextEncoder().encode(result.content));
        identities.push({name:entry.name,sha256:Array.from(new Uint8Array(hash),byte=>byte.toString(16).padStart(2,'0')).join('')});
    }
    return identities;
}
