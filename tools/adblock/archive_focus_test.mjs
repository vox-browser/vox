import assert from 'node:assert/strict';
import test from 'node:test';
import {parseArchiveFocus,restoreArchiveFocus} from './archive_focus.mjs';

test('archive focus validates identity and the supported visible-focus state',()=>{
    assert.equal(parseArchiveFocus(''),null);
    assert.deepEqual(parseArchiveFocus('{"id":"banner","tag":"DIV","focus_visible":true}'),
        {id:'banner',tag:'DIV',focus_visible:true});
    for (const state of [null,{}, {id:'',tag:'DIV',focus_visible:true},
        {id:'banner',tag:'div',focus_visible:true},{id:'banner',tag:'DIV',focus_visible:false}])
        assert.throws(()=>parseArchiveFocus(JSON.stringify(state)),/Archive focus/);
});

test('replay requires the requested focus identity and does not accept a failed focus',async()=>{
    const state={id:'banner',tag:'DIV',focus_visible:true};
    let calls=0;
    await restoreArchiveFocus({evaluate:async expression=>{
        ++calls;assert(expression.includes('preventScroll:true'));return state;
    }},state);
    assert.equal(calls,1);
    await assert.rejects(restoreArchiveFocus({evaluate:async()=>({...state,id:'other'})},state),/did not restore/);
    await restoreArchiveFocus({evaluate:async()=>{throw Error('unrequested action');}},null);
});
