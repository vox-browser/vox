import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import {createOracleTarget} from './oracle_target.mjs';

function fixture() {
    const tabs=[{id:11,url:'https://www.engadget.com/'},{id:12,url:'https://www.engadget.com/'}];
    let marker,removed=[];
    const chrome={runtime:{},tabs:{
        create:(details,callback)=>{marker=details.url;tabs.push({id:73,...details});callback({id:73});},
        query:(_query,callback)=>callback(tabs),
        remove:(ids,callback)=>{removed=Array.from(ids);callback();},
    }};
    const background={evaluate:expression=>vm.runInNewContext(expression,{chrome})};
    const targets=async()=>[
        {id:'other-1',type:'page',url:tabs[0].url},
        {id:'other-2',type:'page',url:tabs[1].url},
        {id:'created',type:'page',url:marker,webSocketDebuggerUrl:'ws://created'},
    ];
    return {background,targets,chrome,getRemoved:()=>removed};
}

test('restored duplicate URLs cannot select another tab or its PageStore',async()=>{
    const f=fixture();
    const result=await createOracleTarget(f.background,f.targets);
    assert.equal(result.tab_id,73);
    assert.equal(result.target.id,'created');
    assert.match(result.initial_url,/^about:blank#vox-oracle-/);
    assert.deepEqual(f.getRemoved(),[11,12]);
    assert.deepEqual(Array.from(result.removed_tab_ids),[11,12]);
});

test('target discovery polls for the created marker and rejects absent or ambiguous targets',async()=>{
    const f=fixture();let attempts=0;
    const result=await createOracleTarget(f.background,async()=>++attempts===1?[]:f.targets(),{pollMs:0});
    assert.equal(result.target.id,'created');assert.equal(attempts,2);
    const absent=fixture();
    await assert.rejects(createOracleTarget(absent.background,async()=>[],{timeoutMs:0}),/did not create its debugger target/);
    assert.deepEqual(absent.getRemoved(),[]);
    const ambiguous=fixture();
    await assert.rejects(createOracleTarget(ambiguous.background,async()=>{
        const targets=await ambiguous.targets();return [...targets,targets.at(-1)];
    }),/multiple debugger targets/);
});

test('tab API failures propagate without silently using a restored target',async()=>{
    const creation=fixture();creation.chrome.tabs.create=(_details,callback)=>callback({});
    await assert.rejects(createOracleTarget(creation.background,creation.targets),/did not return an identity/);
    const removal=fixture();
    removal.chrome.tabs.remove=(_ids,callback)=>{removal.chrome.runtime.lastError={message:'Cannot close tab'};callback();};
    await assert.rejects(createOracleTarget(removal.background,removal.targets),/Cannot close tab/);
});
