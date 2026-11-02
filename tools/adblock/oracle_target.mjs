import crypto from 'node:crypto';

// Create the measured tab through the extension API, then bind CDP by an
// unguessable blank URL. A prepared profile may restore several identical
// pages; a URL or target-list order cannot identify its uBO PageStore.
export async function createOracleTarget(background, targets, {timeoutMs=30000,pollMs=100}={}) {
    const marker='about:blank#vox-oracle-'+crypto.randomUUID();
    const tabId=await background.evaluate(`new Promise((resolve,reject)=>{
        chrome.tabs.create({url:${JSON.stringify(marker)},active:true},tab=>{
            if(chrome.runtime.lastError) reject(Error(chrome.runtime.lastError.message));
            else resolve(tab?.id);
        });
    })`);
    if (!Number.isSafeInteger(tabId) || tabId<=0) throw Error('Oracle tab creation did not return an identity');
    const deadline=Date.now()+timeoutMs;
    let target;
    do {
        const candidates=(await targets()).filter(row=>row.type==='page' && row.url===marker);
        if(candidates.length>1) throw Error('Oracle marker matched multiple debugger targets');
        if(candidates.length===1) {target=candidates[0];break;}
        if(Date.now()>=deadline) throw Error('Oracle tab did not create its debugger target');
        await new Promise(resolve=>setTimeout(resolve,pollMs));
    } while(true);
    const removed=await background.evaluate(`new Promise((resolve,reject)=>{
        chrome.tabs.query({},tabs=>{
            if(chrome.runtime.lastError) return reject(Error(chrome.runtime.lastError.message));
            const ids=tabs.filter(tab=>tab.id!==${tabId}).map(tab=>tab.id);
            if(!ids.length) return resolve([]);
            chrome.tabs.remove(ids,()=>{
                if(chrome.runtime.lastError) reject(Error(chrome.runtime.lastError.message));
                else resolve(ids);
            });
        });
    })`);
    return {target,tab_id:tabId,removed_tab_ids:removed,initial_url:marker};
}
