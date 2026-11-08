module browserjs

import dom
import html
import indexeddb
import loader
import platform

fn indexed_db_index_fixture() !(&Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://idb-index-binding.test/' }
	document := html.parse_navigation_document('<!doctype html>', address, address.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_indexed_db_binding()!
	return runtime, document
}

fn deliver_index_schema_tasks() {
	indexeddb.cleanup_indexed_database_transactions(voidptr(html.main_thread_event_loop()))
	mut tasks := html.main_thread_event_loop().task_queue()
	mut count := 0
	for {
		task := tasks.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .database_access }) or { break }
		task.execute()
		indexeddb.cleanup_indexed_database_transactions(voidptr(html.main_thread_event_loop()))
		count++
		assert count < 100
	}
}

fn test_index_get_and_get_key_are_ordered_native_requests() {
	mut runtime, mut document := indexed_db_index_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.evaluate_host(r'
 globalThis.checks=[];globalThis.opening=indexedDB.open("get-index",1);
 opening.onupgradeneeded=()=>{
  const store=opening.result.createObjectStore("items"),index=store.createIndex("lookup","field");
  store.add({field:"match"},9);
  const get=index.get("match"),key=index.getKey("match");
  checks.push(get.source===index,get.transaction===opening.transaction,get.readyState==="pending");
  get.onsuccess=e=>checks.push(e.target===get,get.result.field==="match",get.result===get.result);
  key.onsuccess=()=>checks.push(key.result===9);
 };opening.onsuccess=()=>checks.push(true);true
 ')!
	deliver_index_schema_tasks()
	assert runtime.evaluate_host('checks.length===8&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}

fn test_index_creation_uses_native_schema_metadata_and_live_names() {
	$if !darwin && !linux { return }
	mut runtime, mut document := indexed_db_index_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 typeof IDBObjectStore.prototype.createIndex==="function"&&IDBObjectStore.prototype.createIndex.length===2;
 ')! == 'true'
	assert runtime.evaluate_host(r'
 globalThis.checks=[];globalThis.opening=indexedDB.open("index-schema",1);
 opening.onupgradeneeded=()=>{
  const db=opening.result,store=db.createObjectStore("items"),names=store.indexNames;
  globalThis.store=store;globalThis.index=store.createIndex("expiry","state.expiresAt",{unique:true});
  checks.push(index instanceof IDBIndex,Object.prototype.toString.call(index)==="[object IDBIndex]",index.objectStore===store,index.objectStore===index.objectStore,index.name==="expiry",index.keyPath==="state.expiresAt",index.unique===true,index.multiEntry===false,names===store.indexNames,names.length===1,names[0]==="expiry");
  index.name="renamed";
  checks.push(index.name==="renamed",names[0]==="renamed",names.contains("renamed"),!names.contains("expiry"));
  const compound=store.createIndex("compound",["a","b"]),path=compound.keyPath;path[0]="changed";
  checks.push(compound.keyPath===path&&JSON.stringify(compound.keyPath)===JSON.stringify(["changed","b"]),compound.unique===false,compound.multiEntry===false);
  const tags=store.createIndex("tags","tags",{multiEntry:true});checks.push(tags.multiEntry===true);
 };
 opening.onsuccess=()=>{checks.push(opening.result.objectStoreNames.contains("items"));opening.result.close();};true
 ')! == 'true'
	deliver_index_schema_tasks()
	assert runtime.evaluate_host('JSON.stringify(checks.map((x,i)=>x?null:i).filter(x=>x!==null))')! == '[]'
	assert runtime.evaluate_host('checks.length')! == '20'
}

fn test_index_key_path_conversion_is_single_pass_and_closes_iterators() {
	$if !darwin && !linux { return }
	mut runtime, mut document := indexed_db_index_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 globalThis.log=[];globalThis.checks=[];globalThis.opening=indexedDB.open("index-conversion",1);
 opening.onupgradeneeded=()=>{
  const store=opening.result.createObjectStore("items");let step=0;
  const path={get [Symbol.iterator](){log.push("iterator");return function(){return {next(){log.push("next:"+step);return step++===0?{value:{toString(){log.push("path");return "field"}},done:false}:{done:true}}}}}};
  const index=store.createIndex({toString(){log.push("name");return "converted"}},path,{get multiEntry(){log.push("multiEntry");return false},get unique(){log.push("unique");return true}});
  checks.push(JSON.stringify(index.keyPath)===JSON.stringify(["field"]),index.unique);
  let closed=false,options=false,number=0;
  const invalid={[Symbol.iterator](){return {next(){number++;return {value:Symbol(),done:false}},return(){closed=true;return {done:true}}}}};
  try{store.createIndex("bad",invalid,{get unique(){options=true;return false}});checks.push(false)}catch(e){checks.push(e instanceof TypeError,closed,!options,number===1)}
  const set=store.createIndex("set",new Set(["a","b"]));checks.push(JSON.stringify(set.keyPath)===JSON.stringify(["a","b"]));
  const marker={};let touched=false;try{store.createIndex("throw",{get [Symbol.iterator](){throw marker}},{get unique(){touched=true}})}catch(e){checks.push(e===marker,!touched)}
  const plain=store.createIndex("plain",{toString(){return "plain.path"}},null);checks.push(plain.keyPath==="plain.path");
 };opening.onsuccess=()=>opening.result.close();true
 ')! == 'true'
	deliver_index_schema_tasks()
	assert runtime.evaluate_host('JSON.stringify(log)')! == '["name","iterator","next:0","path","next:1","multiEntry","unique"]'
	assert runtime.evaluate_host('JSON.stringify(checks.map((x,i)=>x?null:i).filter(x=>x!==null))')! == '[]'
	assert runtime.evaluate_host('checks.length')! == '10'
}

fn test_index_schema_binding_preserves_brands_conversion_and_transaction_errors() {
	$if !darwin && !linux { return }
	mut runtime, mut document := indexed_db_index_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 globalThis.errors=[];globalThis.checks=[];globalThis.opening=indexedDB.open("index-errors",1);
 const record=fn=>{try{fn();errors.push("accepted")}catch(e){errors.push(e.name)}};
 record(()=>new IDBIndex());record(()=>IDBObjectStore.prototype.createIndex.call({},"x","x"));
 record(()=>Object.getOwnPropertyDescriptor(IDBIndex.prototype,"objectStore").get.call({}));
 opening.onupgradeneeded=()=>{
  globalThis.store=opening.result.createObjectStore("items");globalThis.index=store.createIndex("one","field");
  record(()=>store.createIndex("missing"));record(()=>store.createIndex("one","field"));
  record(()=>store.createIndex("invalid",[]));record(()=>store.createIndex("compound",["a"],{multiEntry:true}));
  store.createIndex("two","other");record(()=>{index.name="two"});
  let touched=false;record(()=>IDBObjectStore.prototype.createIndex.call({}, {toString(){touched=true}},"field"));checks.push(!touched);
 };
 opening.onsuccess=()=>{
  const db=opening.result,plain=db.transaction("items").objectStore("items");
  record(()=>plain.createIndex("late","field"));record(()=>store.createIndex("ended","field"));
  const marker={};let same=false;try{plain.createIndex("converted",{toString(){throw marker}})}catch(e){same=e===marker}checks.push(same);
  db.close();
 };true
 ')! == 'true'
	deliver_index_schema_tasks()
	assert runtime.evaluate_host('JSON.stringify(errors)')! == '["TypeError","TypeError","TypeError","TypeError","ConstraintError","SyntaxError","InvalidAccessError","ConstraintError","TypeError","InvalidStateError","TransactionInactiveError"]'
	assert runtime.evaluate_host('checks.every(Boolean)&&checks.length===2')! == 'true'
}

fn test_index_metadata_and_owner_survive_deleted_schema_abort_and_temporary_inputs() {
	$if !darwin && !linux { return }
	mut runtime, mut document := indexed_db_index_fixture()!
	document.enable_native_storage()
	defer { runtime.close(); document.finalize() }
	mut temporary := platform.begin_thread_scratch('IndexedDB index input')
	source := r'
 globalThis.checks=[];globalThis.opening=indexedDB.open("index-retained",1);
 opening.onupgradeneeded=()=>{
  const db=opening.result;globalThis.store=db.createObjectStore("items");globalThis.index=store.createIndex("kept",["nested.key"],{unique:true});
  db.deleteObjectStore("items");
  checks.push(index.objectStore===store,index.name==="kept",index.unique===true,index.multiEntry===false,JSON.stringify(index.keyPath)===JSON.stringify(["nested.key"]));
  opening.transaction.abort();
 };
 opening.onerror=()=>{checks.push(opening.error.name==="AbortError",index.objectStore===store,index.unique===true,JSON.stringify(index.keyPath)===JSON.stringify(["nested.key"]));};true
 '.clone()
	temporary.leave()
	assert runtime.evaluate_host(source)! == 'true'
	temporary.finish()
	gc_collect()
	deliver_index_schema_tasks()
	gc_collect()
	assert runtime.evaluate_host('JSON.stringify(checks.map((x,i)=>x?null:i).filter(x=>x!==null))')! == '[]'
	assert runtime.evaluate_host('checks.length')! == '9'
}

fn test_index_lookup_reuses_schema_handles_across_rename_and_recreation() {
	$if !darwin && !linux { return }
	mut runtime, mut document := indexed_db_index_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 globalThis.checks=[];globalThis.opening=indexedDB.open("index-lookup",1);
 const throws=(name,fn)=>{try{fn();return false}catch(e){return e.name===name}};
 checks.push(IDBObjectStore.prototype.index.length===1,IDBObjectStore.prototype.deleteIndex.length===1,throws("TypeError",()=>IDBObjectStore.prototype.index.call({},"x")));
 opening.onupgradeneeded=()=>{
  const store=opening.result.createObjectStore("items");globalThis.upgradeStore=store;
  const first=store.createIndex("original",["field"]);checks.push(first===store.index("original"),first===store.index("original"));
  first.name="renamed";checks.push(first===store.index("renamed"),throws("NotFoundError",()=>store.index("original")));
  store.deleteIndex("renamed");checks.push(throws("NotFoundError",()=>store.index("renamed")),store.indexNames.length===0,first.name==="renamed");
  const next=store.createIndex("renamed",["other"]);checks.push(next!==first,next===store.index("renamed"),next.keyPath!==first.keyPath,first.keyPath.join()==="field");
  let converted=false;const marker={};try{store.index({toString(){converted=true;throw marker}})}catch(e){checks.push(converted,e===marker)}
 };
 opening.onsuccess=()=>{
  checks.push(throws("InvalidStateError",()=>upgradeStore.index("renamed")));
  const db=opening.result,a=db.transaction("items").objectStore("items"),b=db.transaction("items").objectStore("items");
  checks.push(a.index("renamed")!==b.index("renamed"),a.index("renamed").objectStore===a);db.close();
 };true
 ')! == 'true'
	deliver_index_schema_tasks()
	assert runtime.evaluate_host('checks.length===19&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}
