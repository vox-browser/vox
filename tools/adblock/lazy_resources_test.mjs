import test from 'node:test';
import assert from 'node:assert/strict';
import {restoreResources} from './lazy_resources.mjs';

test('indexed resources hydrate only queried entries and preserve map mutation and order', () => {
    let reads=0;
    const entries = new Map([['first',{content:'first source'}],['second',{content:'second source'}]]);
    const get=entries.get.bind(entries);
    entries.get=key=>{++reads;return get(key);};
    const {resources,aliases}=restoreResources({entries,aliases:new Map([['alias','second']])});
    assert.equal(reads,0); assert.ok(resources instanceof Map);
    assert.equal(resources.size,2); assert.equal(resources.has('first'),true); assert.equal(reads,0);
    assert.equal(aliases.get('alias'),'second');
    assert.equal(resources.get('first').toContent(),'first source'); assert.equal(reads,1);
    assert.equal(typeof get('second').toContent,'undefined');
    const custom={toContent:()=> 'custom'};
    assert.equal(resources.set('third',custom),resources); assert.equal(resources.get('third'),custom);
    assert.deepEqual([...resources.keys()],['first','second','third']);
    assert.deepEqual([...resources.values()].map(v=>v.toContent()),['first source','second source','custom']);
    const receiver={},visited=[];
    resources.forEach(function(value,key,map){assert.equal(this,receiver);assert.equal(map,resources);visited.push(key);},receiver);
    assert.deepEqual(visited,['first','second','third']);
    assert.deepEqual([...resources].map(([key,value])=>[key,value.toContent()]),[['first','first source'],['second','second source'],['third','custom']]);
    assert.equal(resources.delete('second'),true); assert.equal(resources.delete('missing'),false);
    resources.clear(); assert.equal(resources.size,0); assert.equal(resources.get('first'),undefined);
});

test('redirect entries preserve MIME selection, data URLs and independent restoration', () => {
    const make=()=>restoreResources({entries:new Map([
        ['empty',{content:'',redirect:true,data:''}],
        ['noop.js',{content:'void 0',redirect:true,data:'data:text/javascript,void%200'}],
    ]),aliases:new Map()}).resources;
    const first=make(),second=make();
    assert.equal(first.get('empty').toURL({type:'script'}),'data:text/javascript,');
    assert.equal(first.get('empty').toURL({type:'other'}),'data:text/plain,');
    assert.equal(first.get('noop.js').toURL({type:'script'}),'data:text/javascript,void%200');
    first.get('empty').content='changed';
    assert.equal(second.get('empty').toContent(),'');
});
