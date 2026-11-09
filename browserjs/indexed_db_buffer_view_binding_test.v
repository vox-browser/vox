module browserjs

import dom
import html
import indexeddb
import loader

fn buffer_view_binding_fixture() !(&Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://idb-buffer-view.test/' }
	document := html.parse_navigation_document('<!doctype html>', address, address.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_indexed_db_binding()!
	return runtime, document
}

fn drain_buffer_view_binding_tasks(loop &html.EventLoop) {
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

fn test_indexed_db_stores_typed_arrays_and_dataview_with_the_original_buffer_shape() {
	mut runtime, mut document := buffer_view_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
 globalThis.checks=[];globalThis.expected=0;const opening=indexedDB.open("all-views",1);
 opening.onupgradeneeded=()=>{
  const store=opening.result.createObjectStore("items"),Types=[Int8Array,Uint8Array,Uint8ClampedArray,Int16Array,Uint16Array,Int32Array,Uint32Array,Float32Array,Float64Array,BigInt64Array,BigUint64Array];
  if(typeof Float16Array==="function")Types.push(Float16Array);
  for(const Type of [...Types,DataView]){
   const bytes=new Uint8Array(32);for(let i=0;i<32;i++)bytes[i]=i;
   const view=new Type(bytes.buffer,8,Type===DataView?8:8/Type.BYTES_PER_ELEMENT),name=Type.name;
   store.put(view,name);bytes.fill(99);const read=store.get(name);expected++;
   read.onsuccess=()=>{const result=read.result;checks.push(result instanceof Type,result.buffer.byteLength===32,result.byteOffset===8,result.byteLength===8,new Uint8Array(result.buffer).every((v,i)=>v===i));};
  }
 };opening.onsuccess=()=>opening.result.close();true
 ')!
	drain_buffer_view_binding_tasks(html.main_thread_event_loop())
	assert runtime.evaluate_host('expected>=12&&checks.length===expected*5&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify({expected,checks})')!
}

fn test_indexed_db_buffer_view_storage_uses_internal_slots_and_retains_snapshot_bytes() {
	mut runtime, mut document := buffer_view_binding_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	runtime.evaluate_host(r'
 globalThis.checks=[];const opening=indexedDB.open("view-slots",1);
 opening.onupgradeneeded=()=>{
  const store=opening.result.createObjectStore("items"),buffer=new Uint8Array([9,1,2,8]).buffer,view=new Uint8Array(buffer,1,2);
  for(const name of ["buffer","byteOffset","byteLength","length","extra"])Object.defineProperty(view,name,{enumerable:true,get(){throw "author view metadata"}});
  store.put(view,1);buffer.transfer();const read=store.get(1);
  read.onsuccess=()=>{const value=read.result;checks.push(value instanceof Uint8Array,value.byteOffset===1,value.join()==="1,2",new Uint8Array(value.buffer).join()==="9,1,2,8",!("extra" in value));};
  const backing=new ArrayBuffer(8);let rejected=false;
  try{store.put({view:new Uint8Array(backing),buffer:backing},2)}catch(error){rejected=error.name==="DataCloneError"}checks.push(rejected);
 };opening.onsuccess=()=>opening.result.close();true
 ')!
	drain_buffer_view_binding_tasks(html.main_thread_event_loop())
	assert runtime.evaluate_host('checks.length===6&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}

fn test_worker_indexed_db_batch_values_preserve_typed_arrays() {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://idb-buffer-view-worker.test/worker.js' }
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
 globalThis.checked=false;const opening=indexedDB.open("worker-views",1);
 opening.onupgradeneeded=()=>{const store=opening.result.createObjectStore("items");store.put(new Uint8Array([1,2,3]),1);const all=store.getAllRecords();all.onsuccess=()=>{const value=all.result[0].value;checked=value instanceof Uint8Array&&value.join()==="1,2,3"}};
 opening.onsuccess=()=>opening.result.close();true
 ')!
	drain_buffer_view_binding_tasks(environment.settings.responsible_event_loop())
	assert runtime.evaluate_host('checked')! == 'true'
}
