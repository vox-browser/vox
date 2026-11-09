module browserjs

import dom
import html
import indexeddb
import loader

fn batch_binding_fixture() !(&Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://idb-batch-binding.test/' }
	document := html.parse_navigation_document('<!doctype html>', address, address.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_indexed_db_binding()!
	return runtime, document
}

fn drain_batch_binding_tasks(loop &html.EventLoop) {
	mut queue := loop.task_queue()
	for turn in 0 .. 300 {
		indexeddb.cleanup_indexed_database_transactions(voidptr(loop))
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .database_access
		}) or { break }
		task.execute()
		assert turn < 299
	}
}

fn test_batch_binding_returns_native_arrays_and_record_snapshots_with_request_identity() {
	mut runtime, mut document := batch_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
 globalThis.checks=[];const opening=indexedDB.open("snapshots",1);
 opening.onupgradeneeded=()=>{
  const db=opening.result,store=db.createObjectStore("items"),index=store.createIndex("lookup","field");
  for(let key=1;key<=3;key++)store.put({field:key<3?"a":"b"},[key]);
  const values=store.getAll(),keys=store.getAllKeys(),records=store.getAllRecords(),indexValues=index.getAll(),indexKeys=index.getAllKeys(),indexRecords=index.getAllRecords();
  for(const request of [values,keys,records,indexValues,indexKeys,indexRecords])checks.push(request instanceof IDBRequest,request.readyState==="pending",request.transaction===opening.transaction);
  checks.push(values.source===store,indexValues.source===index);
  values.onsuccess=()=>checks.push(Array.isArray(values.result),values.result===values.result,values.result.length===3,values.result[2].field==="b");
  keys.onsuccess=()=>checks.push(JSON.stringify(keys.result)==="[[1],[2],[3]]");
  records.onsuccess=()=>{
   const result=records.result,record=result[0],key=record.key;
   checks.push(record instanceof IDBRecord,!(record instanceof EventTarget),Object.prototype.toString.call(record)==="[object IDBRecord]",record.value===record.value,key!==record.key,key!==record.primaryKey);
   key.push("author");record.value.field="changed";checks.push(record.key.join()==="1",record.value.field==="changed");
   const read=store.get([1]);read.onsuccess=()=>checks.push(read.result.field==="a");
  };
  indexValues.onsuccess=()=>checks.push(indexValues.result.length===3);
  indexKeys.onsuccess=()=>checks.push(JSON.stringify(indexKeys.result)==="[[1],[2],[3]]");
  indexRecords.onsuccess=()=>checks.push(indexRecords.result[0].key==="a",indexRecords.result[2].primaryKey[0]===3);
 };opening.onsuccess=()=>opening.result.close();true
 ')!
	drain_batch_binding_tasks(html.main_thread_event_loop())
	assert runtime.evaluate_host('checks.length===38&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}

fn test_batch_binding_options_preserve_direction_count_and_explicit_commit() {
	mut runtime, mut document := batch_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
 globalThis.checks=[];const opening=indexedDB.open("options",1);
 opening.onupgradeneeded=()=>{const store=opening.result.createObjectStore("items");store.createIndex("lookup","field")};
 opening.onsuccess=()=>{
  const db=opening.result,tx=db.transaction("items","readwrite"),store=tx.objectStore("items"),index=store.index("lookup");
  for(let key=1;key<=3;key++)store.put({field:key<3?"a":"b"},key);
  const legacy=store.getAll(IDBKeyRange.lowerBound(2),1),options=store.getAllKeys({count:1,direction:"prev"},9),zero=store.getAllKeys(null,0),maximum=store.getAllKeys(undefined,4294967295),unique=index.getAllRecords({direction:"prevunique"});
  legacy.onsuccess=()=>checks.push(legacy.result.length===1,legacy.result[0].field==="a");
  options.onsuccess=()=>checks.push(JSON.stringify(options.result)==="[3]");zero.onsuccess=()=>checks.push(JSON.stringify(zero.result)==="[1,2,3]");
  maximum.onsuccess=()=>checks.push(maximum.result.length===3);unique.onsuccess=()=>checks.push(unique.result.length===2,unique.result[0].key==="b",unique.result[1].primaryKey===1);
  tx.oncomplete=()=>{checks.push(true);db.close()};tx.commit();
 };true
 ')!
	drain_batch_binding_tasks(html.main_thread_event_loop())
	assert runtime.evaluate_host('checks.length===9&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}

fn test_batch_binding_brands_webidl_conversion_and_deleted_source_error_order() {
	mut runtime, mut document := batch_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
 globalThis.checks=[];const rejects=(name,operation)=>{try{operation();return false}catch(error){return error.name===name}};
 let touched=false;const marker={},throwing={get count(){touched=true;throw marker}};
 checks.push(rejects("TypeError",()=>new IDBRecord()),rejects("TypeError",()=>Object.getOwnPropertyDescriptor(IDBRecord.prototype,"key").get.call({})));
 for(const Type of [IDBObjectStore,IDBIndex])for(const method of ["getAll","getAllKeys","getAllRecords"])checks.push(Type.prototype[method].length===0,rejects("TypeError",()=>Type.prototype[method].call({},throwing)));
 checks.push(!touched);const opening=indexedDB.open("conversion",1);
 opening.onupgradeneeded=()=>{
  const db=opening.result,store=db.createObjectStore("items"),index=store.createIndex("lookup","field");
  for(const count of [-1,4294967296,NaN,Infinity])checks.push(rejects("TypeError",()=>store.getAll(null,count)),rejects("TypeError",()=>index.getAllRecords({count})));
  checks.push(rejects("TypeError",()=>store.getAllRecords(1)),rejects("TypeError",()=>index.getAllKeys({direction:"invalid"})));
  try{store.getAllRecords(throwing);checks.push(false)}catch(error){checks.push(error===marker)}touched=false;
  db.deleteObjectStore("items");checks.push(rejects("InvalidStateError",()=>store.getAll(throwing)),!touched);
  const order=[],dictionary={get count(){order.push("count");return 1},get direction(){order.push("direction");return "next"},get query(){order.push("query");return null}};
  checks.push(rejects("InvalidStateError",()=>index.getAllRecords(dictionary)),order.join()==="count,direction,query");
 };opening.onsuccess=()=>opening.result.close();true
 ')!
	drain_batch_binding_tasks(html.main_thread_event_loop())
	assert runtime.evaluate_host('checks.length===30&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}

fn test_worker_batch_queries_return_records_from_the_worker_transaction_queue() {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://idb-batch-worker.test/worker.js' }
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
 globalThis.checks=[];const opening=indexedDB.open("worker-batch",1);
 opening.onupgradeneeded=()=>{const store=opening.result.createObjectStore("items"),index=store.createIndex("lookup","field");store.put({field:"value"},1);
  const values=store.getAll(),keys=index.getAllKeys(),records=index.getAllRecords();
  values.onsuccess=()=>checks.push(values.result[0].field==="value");keys.onsuccess=()=>checks.push(keys.result[0]===1);
  records.onsuccess=()=>checks.push(records.result[0] instanceof IDBRecord,records.result[0].key==="value",records.result[0].primaryKey===1);
 };opening.onsuccess=()=>opening.result.close();true
 ')!
	drain_batch_binding_tasks(environment.settings.responsible_event_loop())
	assert runtime.evaluate_host('checks.length===5&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}
