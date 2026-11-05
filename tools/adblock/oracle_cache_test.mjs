import assert from 'node:assert/strict';
import test from 'node:test';
import {prepareOraclePageCache} from './oracle_cache.mjs';

test('cold page preparation clears inherited HTTP cache and bypasses site workers', async () => {
    const calls=[];
    const page={send:async (...args)=>{calls.push(args);return {};}};
    const result=await prepareOraclePageCache(page,{httpCachePolicy:'empty',serviceWorkerPolicy:'bypass'});
    assert.deepEqual(calls,[['Network.setBypassServiceWorker',{bypass:true}],['Network.clearBrowserCache']]);
    assert.deepEqual(result,{http_cache_policy:'empty',http_cache_cleared:true,service_worker_policy:'bypass'});
});

test('a complete-cache replay keeps warmed HTTP responses while bypassing site workers', async () => {
    const calls=[];
    const result=await prepareOraclePageCache({send:async (...args)=>calls.push(args)},
        {httpCachePolicy:'preserve',serviceWorkerPolicy:'bypass'});
    assert.deepEqual(calls,[['Network.setBypassServiceWorker',{bypass:true}]]);
    assert.equal(result.http_cache_cleared,false);
});

test('standalone oracle defaults preserve its existing page cache and worker policy', async () => {
    const calls=[];
    const result=await prepareOraclePageCache({send:async (...args)=>calls.push(args)});
    assert.deepEqual(calls,[['Network.setBypassServiceWorker',{bypass:false}]]);
    assert.equal(result.http_cache_policy,'preserve');
    assert.equal(result.service_worker_policy,'allow');
});

test('invalid policies fail before sending page commands', async () => {
    const page={send:()=>{throw Error('Unexpected page command');}};
    await assert.rejects(prepareOraclePageCache(page,{httpCachePolicy:'ignored'}),/Unsupported HTTP/);
    await assert.rejects(prepareOraclePageCache(page,{serviceWorkerPolicy:'ignored'}),/Unsupported service worker/);
});

test('cache clear failure prevents navigation preparation from qualifying', async () => {
    const page={send:async method=>{if(method==='Network.clearBrowserCache')throw Error('Cache clear failed');}};
    await assert.rejects(prepareOraclePageCache(page,{httpCachePolicy:'empty'}),/Cache clear failed/);
});
