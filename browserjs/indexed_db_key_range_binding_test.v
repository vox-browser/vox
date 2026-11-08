module browserjs

import dom
import html
import indexeddb
import loader

fn key_range_binding_fixture() !(&Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://idb-key-range.test/' }
	document := html.parse_navigation_document('<!doctype html>', address, address.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_indexed_db_binding()!
	return runtime, document
}

fn test_indexed_db_key_range_metadata_receivers_and_required_arguments() {
	mut runtime, mut document := key_range_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const range=IDBKeyRange.only.call({},1),rejects=(name,operation)=>{try{operation();return false}catch(error){return error.name===name}};
 let touched=false;const key=[];Object.defineProperty(key,"0",{get(){touched=true;return 1}});
 range instanceof IDBKeyRange&&!(range instanceof EventTarget)&&Object.prototype.toString.call(range)==="[object IDBKeyRange]"&&
 IDBKeyRange.length===0&&IDBKeyRange.only.length===1&&IDBKeyRange.lowerBound.length===1&&IDBKeyRange.upperBound.length===1&&IDBKeyRange.bound.length===2&&IDBKeyRange.prototype.includes.length===1&&
 Object.getOwnPropertyDescriptor(IDBKeyRange.prototype,"lower").enumerable&&
 rejects("TypeError",()=>new IDBKeyRange())&&rejects("TypeError",()=>IDBKeyRange.only())&&rejects("TypeError",()=>IDBKeyRange.bound(1))&&
 rejects("TypeError",()=>range.includes())&&rejects("TypeError",()=>IDBKeyRange.prototype.includes.call({},key))&&!touched&&
 rejects("TypeError",()=>Object.getOwnPropertyDescriptor(IDBKeyRange.prototype,"lower").get.call({}))&&
 rejects("TypeError",()=>Object.getOwnPropertyDescriptor(IDBRequest.prototype,"result").get.call(range));
 ')! == 'true'
}

fn test_indexed_db_key_range_bounds_includes_and_fresh_boundary_values() {
	mut runtime, mut document := key_range_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const input=[new Date(5),new Uint8Array([1,2])],range=IDBKeyRange.only(input),first=range.lower;
 input[0].setTime(8);input[1][0]=9;first[0].setTime(10);new Uint8Array(first[1])[0]=11;
 const lower=IDBKeyRange.lowerBound(2,true),upper=IDBKeyRange.upperBound(4),closed=IDBKeyRange.bound(2,4),open=IDBKeyRange.bound(2,4,true,true);
 range.lower!==range.lower&&range.lower!==range.upper&&range.lower[0].getTime()===5&&new Uint8Array(range.upper[1]).join()==="1,2"&&range.includes([new Date(5),new Uint8Array([1,2])])&&
 lower.lower===2&&lower.upper===undefined&&lower.lowerOpen&&lower.upperOpen&&!lower.includes(2)&&lower.includes(3)&&
 upper.lower===undefined&&upper.upper===4&&upper.lowerOpen&&!upper.upperOpen&&upper.includes(4)&&!upper.includes(5)&&
 closed.includes(2)&&closed.includes(4)&&!closed.lowerOpen&&!closed.upperOpen&&!open.includes(2)&&open.includes(3)&&!open.includes(4);
 ')! == 'true'
}

fn test_indexed_db_key_range_conversion_order_and_original_exceptions() {
	mut runtime, mut document := key_range_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 const marker={},throwing=[];let reads=0;Object.defineProperty(throwing,"0",{get(){reads++;throw marker}});
 let first=false,second=false,includes=false,order=false;
 try{IDBKeyRange.bound(throwing,throwing)}catch(error){first=error===marker}
 try{IDBKeyRange.bound([1],throwing)}catch(error){second=error===marker}
 try{IDBKeyRange.bound({},throwing)}catch(error){order=error instanceof DOMException&&error.name==="DataError"}
 try{IDBKeyRange.only(1).includes(throwing)}catch(error){includes=error===marker}
 const invalid=[undefined,null,{},Symbol(),true,()=>{}];
 const invalids=invalid.every(key=>["only","lowerBound","upperBound"].every(method=>{try{IDBKeyRange[method](key);return false}catch(error){return error instanceof DOMException&&error.name==="DataError"}}));
 let reversed=false;try{IDBKeyRange.bound(4,2)}catch(error){reversed=error.name==="DataError"}
 const boolean={valueOf(){throw "ToBoolean must not call author code"}};
 first&&second&&order&&includes&&reads===3&&invalids&&reversed&&IDBKeyRange.lowerBound(1,boolean).lowerOpen;
 ')! == 'true'
}

fn test_indexed_db_store_and_index_queries_accept_ranges_and_keep_request_owners() {
	mut runtime, mut document := key_range_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.checks=[];globalThis.seen=[];const opening=indexedDB.open("range-queries",1);
 opening.onupgradeneeded=()=>{const store=opening.result.createObjectStore("items");store.createIndex("lookup","field");for(let key=1;key<=4;key++)store.add({field:key},key)};
 opening.onsuccess=()=>{
  const db=opening.result,tx=db.transaction("items"),store=tx.objectStore("items"),index=store.index("lookup"),range=IDBKeyRange.bound(2,3);
  const count=store.count(range),get=store.get(IDBKeyRange.lowerBound(3)),indexGet=index.get(IDBKeyRange.upperBound(2)),indexKey=index.getKey(IDBKeyRange.lowerBound(3)),cursor=store.openCursor(range),indexCursor=index.openKeyCursor(range,"prev");
  checks.push(count.source===store,count.transaction===tx,get.source===store,indexGet.source===index,indexKey.source===index,cursor.source===store,indexCursor.source===index);
  count.onsuccess=()=>checks.push(count.result===2);get.onsuccess=()=>checks.push(get.result.field===3);
  indexGet.onsuccess=()=>checks.push(indexGet.result.field===1);indexKey.onsuccess=()=>checks.push(indexKey.result===3);
  cursor.onsuccess=()=>{if(cursor.result){seen.push(cursor.result.key);cursor.result.continue()}};
  indexCursor.onsuccess=()=>{if(indexCursor.result){seen.push(-indexCursor.result.key);indexCursor.result.continue()}};
  tx.oncomplete=()=>db.close();
 };true
 ')! == 'true'
	loop := html.main_thread_event_loop()
	mut queue := loop.task_queue()
	for turn in 0 .. 200 {
		indexeddb.cleanup_indexed_database_transactions(voidptr(loop))
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .database_access
		}) or { break }
		task.execute()
		assert turn < 199
	}
	assert runtime.evaluate_host('checks.length===11&&checks.every(Boolean)&&JSON.stringify(seen)==="[2,-3,3,-2]"')! == 'true', runtime.evaluate_host('JSON.stringify({checks,seen})')!
}

fn test_indexed_db_key_range_is_exposed_in_worker_realms() {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://idb-key-range-worker.test/worker.js' }
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
	assert runtime.evaluate_host('typeof window==="undefined"&&IDBKeyRange.bound(1,3).includes(2)&&IDBKeyRange.only("key") instanceof IDBKeyRange')! == 'true'
}
