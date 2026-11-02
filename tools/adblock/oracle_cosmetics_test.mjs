import assert from 'node:assert/strict';
import test from 'node:test';
import vm from 'node:vm';
import {collectOracleCosmetics} from './oracle_cosmetics.mjs';

const request={url:'https://www.wired.com/',hostname:'www.wired.com',domain:'wired.com',tabId:47};
function fixture({generic=true,specific=true,url=request.url,enabled=true}={}) {
    const calls=[];
    const store={rawURL:url,tabId:47,getNetFilteringSwitch:()=>enabled,
        shouldApplyGenericCosmeticFilters:frame=>{assert.equal(frame,0);return generic;},
        shouldApplySpecificCosmeticFilters:frame=>{assert.equal(frame,0);return specific;}};
    const cosmetic={
        removeFromSelectorCache:(...args)=>calls.push(['cache',...args]),
        retrieveSpecificSelectors:(details,options)=>{
            calls.push(['specific',details,options]);
            return {injectedCSS:options.noSpecificCosmeticFiltering?'':'.publisher{display:none!important}',
                proceduralFilters:options.noSpecificCosmeticFiltering?[]:['publisher-procedural'],
                exceptionFilters:['.content']};
        },
        retrieveGenericSelectors:details=>{
            calls.push(['generic',details]);
            return {injectedCSS:'.advert{display:none!important}'};
        },
    };
    const scriptlets={retrieve:details=>{
        calls.push(['scriptlets',details]);return {filters:['publisher-scriptlet']};
    }};
    return {stores:new Map([[47,store]]),store,cosmetic,scriptlets,calls};
}
function collect(f) {
    // Exercise the exact self-contained function serialized into CDP too.
    return vm.runInNewContext('('+collectOracleCosmetics.toString()+')', {})(
        f.stores,f.cosmetic,f.scriptlets,request,['.ad','.ad','#banner','']);
}

test('generichide exceptions keep publisher filters and scriptlets without querying generics',()=>{
    const f=fixture({generic:false});
    const result=collect(f);
    assert.equal(result.css,'.publisher{display:none!important}');
    assert.deepEqual(Array.from(result.procedural),['publisher-procedural']);
    assert.deepEqual(Array.from(result.filters),['publisher-scriptlet']);
    assert.equal(result.policy.generic_enabled,false);
    assert.equal(result.policy.specific_enabled,true);
    assert.equal(result.policy.tab_id,47);
    assert.equal(f.calls.some(call=>call[0]==='generic'),false);
    assert.equal(f.calls.find(call=>call[0]==='specific')[2].noGenericCosmeticFiltering,true);
});

test('specifichide exceptions retain generic filters and pass exceptions to the surveyor',()=>{
    const f=fixture({specific:false});
    const result=collect(f);
    assert.equal(result.css,'\n.advert{display:none!important}');
    assert.equal(result.procedural.length,0);
    assert.deepEqual(Array.from(result.filters),['publisher-scriptlet']);
    const [,details]=f.calls.find(call=>call[0]==='generic');
    assert.equal(details.tabId,47);
    assert.equal(details.frameId,0);
    assert.deepEqual(details.exceptions,['.content']);
    assert.equal(details.hashes.length,2);
});

test('normal tabs retain both filter sets and combined exceptions retain only scriptlets',()=>{
    const normal=collect(fixture());
    assert.equal(normal.css,'.publisher{display:none!important}\n.advert{display:none!important}');
    const disabled=collect(fixture({generic:false,specific:false}));
    assert.equal(disabled.css,'');
    assert.equal(disabled.procedural.length,0);
    assert.deepEqual(Array.from(disabled.filters),['publisher-scriptlet']);
});

test('missing, disabled and unrelated captured tabs cannot supply an oracle policy',()=>{
    for(const f of [fixture({url:'https://other.example/'}),fixture({enabled:false})]) {
        assert.throws(()=>collect(f),/captured full-uBO tab/);
        assert.equal(f.calls.length,0);
    }
    const missing=fixture();missing.stores.clear();
    assert.throws(()=>collect(missing),/captured full-uBO tab/);
    const ambiguous=fixture();ambiguous.stores.set(48,{...ambiguous.store,tabId:48});
    assert.equal(collect(ambiguous).policy.tab_id,47);
    ambiguous.stores.delete(47);
    assert.throws(()=>collect(ambiguous),/captured full-uBO tab/);
});
