module main

import browserjs

fn tag_collection_fast_read_fixture() string {
	return r'
const __state={operations:[]},__dirtyElementStates=new Set();
const __elementRecords=new WeakMap(),__elementRecordGet=WeakMap.prototype.get,__elementApply=Reflect.apply;
function Element(){};const document={};
let nativeVersion="1",members=[{id:"first"}],queries=0,versionReads=0;
globalThis.__ladybirdDOMTreeVersion=function(){versionReads++;return nativeVersion;};
function __queryElement(value){return value;}
function __classCollection(key,name,read){return {get length(){return read().length;},item(index){return read()[index];}};}
function __queryElements(key,action,input){
 queries++;
 if(__state.operations.length||__dirtyElementStates.size){nativeVersion=String(+nativeVersion+1);__state.operations=[];__dirtyElementStates.clear();}
 const request=JSON.parse(input);return {version:nativeVersion,elements:request.version===nativeVersion?null:members};
}
' + compact_tag_collection_bootstrap()
}

fn test_tag_collection_unchanged_reads_avoid_the_json_query_boundary() {
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	assert runtime.evaluate_host(tag_collection_fast_read_fixture() + r'
const collection=__tagCollection("root","*");
if(collection.length!==1)throw new Error("initial membership");
for(let index=0;index<1024;index++)if(collection.item(0)!==members[0])throw new Error("member identity");
if(queries!==1||versionReads!==1024)throw new Error("unchanged reads repeated JSON queries");
// Capture the native reader before author code can replace its global slot.
globalThis.__ladybirdDOMTreeVersion=()=>"stale";
if(collection.length!==1||queries!==1||versionReads!==1025)throw new Error("native version reader replaced");
true;
')! == 'true'
}

fn test_tag_collection_fast_reads_flush_pending_edits_and_observe_native_versions() {
	mut runtime := browserjs.Runtime.create()
	defer { runtime.close() }
	assert runtime.evaluate_host(tag_collection_fast_read_fixture() + r'
const collection=__tagCollection("root","i");collection.length;
members=[{id:"second"},{id:"third"}];nativeVersion="2";
if(collection.length!==2||queries!==2)throw new Error("native mutation stayed cached");
__state.operations.push({op:"appendCreated"});members.push({id:"fourth"});
if(collection.length!==3||queries!==3)throw new Error("pending operation was not flushed");
__dirtyElementStates.add({textContentDirty:true});members=[];
if(collection.length!==0||queries!==4)throw new Error("pending content edit was not flushed");
collection.length;if(queries!==4)throw new Error("clean read used JSON query");
true;
')! == 'true'
}
