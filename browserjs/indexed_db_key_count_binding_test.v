module browserjs

import dom
import html
import indexeddb
import loader

fn key_count_binding_fixture() !(&Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://idb-key-count.test/' }
	document := html.parse_navigation_document('<!doctype html>', address, address.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_indexed_db_binding()!
	return runtime, document
}

fn drain_key_count_tasks(loop &html.EventLoop) {
	mut queue := loop.task_queue()
	for turn in 0 .. 200 {
		indexeddb.cleanup_indexed_database_transactions(voidptr(loop))
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .database_access
		}) or { break }
		task.execute()
		assert turn < 199
	}
}

fn test_indexed_db_key_lookup_and_index_count_are_native_ordered_requests() {
	mut runtime, mut document := key_count_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
 globalThis.checks=[];const opening=indexedDB.open("key-count",1);
 opening.onupgradeneeded=()=>{const store=opening.result.createObjectStore("items");store.createIndex("lookup","field")};
 opening.onsuccess=()=>{
  const db=opening.result,tx=db.transaction("items","readwrite"),store=tx.objectStore("items"),index=store.index("lookup");
  store.put({field:"a"},[1]);store.put({field:"b"},[2]);store.put({field:"a"},[3]);
  const key=store.getKey(IDBKeyRange.lowerBound([2])),missing=store.getKey([9]),count=index.count(IDBKeyRange.only("a")),all=index.count(),empty=index.count("missing");
  for(const request of [key,missing,count,all,empty])checks.push(request instanceof IDBRequest,request.readyState==="pending",request.transaction===tx);
  checks.push(key.source===store,count.source===index);
  key.onsuccess=()=>{const old=key.result;checks.push(old===key.result,old.join()==="2");old.push("author");checks.push(key.result===old)};
  missing.onsuccess=()=>checks.push(missing.result===undefined);count.onsuccess=()=>checks.push(count.result===2);
  all.onsuccess=()=>checks.push(all.result===3);empty.onsuccess=()=>checks.push(empty.result===0);
  tx.oncomplete=()=>{checks.push(true);db.close()};tx.commit();
 };true
 ')!
	drain_key_count_tasks(html.main_thread_event_loop())
	assert runtime.evaluate_host('checks.length===25&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}

fn test_indexed_db_key_count_query_validation_preserves_source_and_conversion_order() {
	mut runtime, mut document := key_count_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
 globalThis.checks=[];const rejects=(name,operation)=>{try{operation();return false}catch(error){return error.name===name}};
 checks.push(IDBObjectStore.prototype.getKey.length===1,IDBIndex.prototype.count.length===0);
 const marker={},throwing=[];let touched=false;Object.defineProperty(throwing,"0",{get(){touched=true;throw marker}});
 checks.push(rejects("TypeError",()=>IDBObjectStore.prototype.getKey.call({},throwing)),rejects("TypeError",()=>IDBIndex.prototype.count.call({},throwing)),!touched);
 const opening=indexedDB.open("key-count-validation",1);
 opening.onupgradeneeded=()=>{
  const db=opening.result,store=db.createObjectStore("items"),index=store.createIndex("lookup","field");
  checks.push(rejects("TypeError",()=>store.getKey()),rejects("DataError",()=>store.getKey(null)),rejects("DataError",()=>index.count({})));
  try{index.count(throwing);checks.push(false)}catch(error){checks.push(error===marker)}touched=false;
  db.deleteObjectStore("items");
  checks.push(rejects("InvalidStateError",()=>store.getKey(throwing)),rejects("InvalidStateError",()=>index.count(throwing)),!touched);
 };opening.onsuccess=()=>opening.result.close();true
 ')!
	drain_key_count_tasks(html.main_thread_event_loop())
	assert runtime.evaluate_host('checks.length===12&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}

fn test_worker_indexed_db_key_lookup_and_index_count_use_the_worker_queue() {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://idb-key-count-worker.test/worker.js' }
	mut document := html.parse_navigation_document('<!doctype html>', address, address.origin(), none)!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut realm := &html.ScriptingRealm{}
	scope := html.DedicatedWorkerGlobalScope.create(address, html.WorkerOptions{}, realm)
	environment := html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm, settings.serialize(), 1)
	mut runtime := Runtime.create_for_worker()
	mut global := WorkerGlobalHost.create(environment)!
	defer {
		runtime.close()
		document.finalize()
	}
	global.install(mut runtime)!
	runtime.install_indexed_db_binding()!
	runtime.evaluate_host(r'
 globalThis.checks=[];const opening=indexedDB.open("worker-key-count",1);
 opening.onupgradeneeded=()=>{const store=opening.result.createObjectStore("items");store.createIndex("lookup","field");store.put({field:"value"},1)};
 opening.onsuccess=()=>{const db=opening.result,tx=db.transaction("items"),store=tx.objectStore("items"),index=store.index("lookup"),key=store.getKey(1),count=index.count("value");
  key.onsuccess=()=>checks.push(key.result===1,key.source===store);count.onsuccess=()=>checks.push(count.result===1,count.source===index);
  tx.oncomplete=()=>db.close();
 };true
 ')!
	drain_key_count_tasks(environment.settings.responsible_event_loop())
	assert runtime.evaluate_host('checks.length===4&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}
