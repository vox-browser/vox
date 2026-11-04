import assert from 'node:assert/strict';
import test from 'node:test';
import {oracleTabEntries} from './oracle_network.mjs';

test('network observations belong to the captured tab, including its child frames', () => {
    const main = {tabId:7,frameId:0,url:'https://slate.com/'};
    const child = {tabId:7,frameId:5,url:'https://child.test/frame'};
    const restored = {tabId:2,frameId:0,url:'https://slate.com/'};
    const worker = {tabId:-1,url:'https://slate.com/tracker'};
    const absent = {url:'https://slate.com/'};
    assert.deepEqual(oracleTabEntries([restored,main,worker,child,absent],7),[main,child]);
});

test('header decisions use the same captured tab ownership', () => {
    const owned = {tabId:3,phase:'response',observed:{blocked:true}};
    const background = {tabId:-1,phase:'response',observed:{blocked:false}};
    assert.deepEqual(oracleTabEntries([background,owned],3),[owned]);
});

test('missing or ambiguous tab ownership fails before comparing decisions', () => {
    for (const id of [undefined,null,-1,0,'7',1.5,NaN])
        assert.throws(() => oracleTabEntries([],id),/tab identity/);
    assert.deepEqual(oracleTabEntries([],7),[]);
});
