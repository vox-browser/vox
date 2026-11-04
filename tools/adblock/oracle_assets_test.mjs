import assert from 'node:assert/strict';
import {test} from 'node:test';
import crypto from 'node:crypto';
import vm from 'node:vm';
import {installOracleLists,oracleAssetIdentities} from './oracle_assets.mjs';

test('pinned list installation persists disabled updates and stops the existing schedule before replacing bytes',async()=>{
    const calls=[],lists=[{name:'list-one',content:'recorded filters'}];
    const u={userSettings:{autoUpdate:true},
        saveUserSettings(){assert.equal(this.userSettings.autoUpdate,false);calls.push('save-settings');},
        async scheduleAssetUpdater(){assert.equal(this.userSettings.autoUpdate,false);calls.push('stop-schedule');},
        async saveUserFilters(value){assert.equal(value,'');calls.push('empty-user-filters');},
        async saveSelectedFilterLists(names){this.selectedFilterLists=names;calls.push('select');},
        async loadFilterLists(){calls.push('load');}};
    const a={updateStop(){calls.push('stop-active-update');},
        async put(name,content){assert.equal(name,lists[0].name);assert.equal(content,lists[0].content);calls.push('put');},
        async remove(pattern){assert(pattern.test('compiled/list-one'));calls.push('remove-compiled');}};
    assert.deepEqual(await installOracleLists(u,a,lists),['list-one']);
    assert.deepEqual(calls,['save-settings','stop-schedule','stop-active-update','empty-user-filters','select','put','remove-compiled','load']);
});

test('oracle hashes cover the actual asset bytes and the same code runs in the extension context',async()=>{
    const content='Recorded filters\nUnicode: Пикабу\n';
    const assets={get:async name=>({content:name==='recorded'?content:'different'})};
    const entries=[{name:'recorded'},{name:'changed'}];
    const identities=await oracleAssetIdentities(assets,entries);
    assert.equal(identities[0].sha256,crypto.createHash('sha256').update(content).digest('hex'));
    assert.notEqual(identities[0].sha256,identities[1].sha256);
    const isolated=vm.runInNewContext('('+oracleAssetIdentities.toString()+')',
        {crypto:crypto.webcrypto,TextEncoder,Uint8Array});
    assert.equal(JSON.stringify(await isolated(assets,entries)),JSON.stringify(identities));
    await assert.rejects(oracleAssetIdentities({get:async()=>({error:'missing'})},entries),/Missing oracle list/);
});
