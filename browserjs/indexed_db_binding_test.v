module browserjs

import dom
import html
import indexeddb
import loader
import platform

fn indexed_db_fixture() !(&Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{ value: 'https://idb-binding.test/' }
	document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_indexed_db_binding()!
	return runtime, document
}

fn deliver_indexed_db_binding_tasks() {
	indexeddb.cleanup_indexed_database_transactions(voidptr(html.main_thread_event_loop()))
	mut queue := html.main_thread_event_loop().task_queue()
	mut count := 0
	for {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .database_access
		}) or { break }
		task.execute()
		indexeddb.cleanup_indexed_database_transactions(voidptr(html.main_thread_event_loop()))
		count++
		assert count < 100
	}
}

fn test_indexed_db_binding_upgrade_requests_share_native_identity_and_finish_in_order() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := indexed_db_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.order=[];globalThis.checks=[];globalThis.opening=indexedDB.open("ordered",1);
 checks.push(indexedDB===indexedDB,opening instanceof IDBOpenDBRequest,opening instanceof IDBRequest,opening instanceof EventTarget,opening.readyState==="pending",opening.source===null,opening.transaction===null);
 let pending=false;try{opening.result}catch(e){pending=e instanceof DOMException&&e.name==="InvalidStateError"}checks.push(pending);
 opening.onupgradeneeded=event=>{
  order.push("upgrade");globalThis.db=opening.result;const tx=opening.transaction;globalThis.tx=tx;
  checks.push(event instanceof IDBVersionChangeEvent,event instanceof Event,event.isTrusted,event.oldVersion===0,event.newVersion===1,event.target===opening,opening.readyState==="done",opening.error===null,tx.db===db,tx.mode==="versionchange");
  const names=db.objectStoreNames;globalThis.store=db.createObjectStore("items");
  checks.push(names===db.objectStoreNames,names instanceof DOMStringList,names.length===1,names[0]==="items",names.item(1)===null,names.contains("items"),[...names].join()==="items",tx.objectStore("items")===store,store.transaction===tx,store.keyPath===null,store.autoIncrement===false);
  const value={text:"before",date:new Date(17),bytes:new Uint8Array([3,4]).buffer};const put=store.put(value,"key");value.text="after";
  checks.push(put.source===store,put.transaction===tx,put.readyState==="pending");
  put.onsuccess=event=>{order.push("put");checks.push(event.isTrusted,event.target===put,put.result==="key");
   const get=store.get("key");get.onsuccess=()=>{order.push("get");const result=get.result;checks.push(result===get.result,result!==value,result.text==="before",result.date instanceof Date,result.date.getTime()===17,result.bytes instanceof ArrayBuffer,new Uint8Array(result.bytes)[1]===4);};
  };
  tx.oncomplete=event=>{order.push("complete");checks.push(event.isTrusted,event.target===tx,tx.error===null);};
 };
 opening.onsuccess=()=>{order.push("open");checks.push(opening.result===db,opening.transaction===null,opening.error===null,db.version===1,db.name==="ordered");};
 order.length===0&&checks.every(Boolean);
 ')! == 'true'
	deliver_indexed_db_binding_tasks()
	assert runtime.evaluate_host('JSON.stringify({order,failed:checks.map((v,i)=>v?null:i).filter(v=>v!==null)})')! == '{"order":["upgrade","put","get","complete","open"],"failed":[]}'
}

fn test_indexed_db_binding_cancelled_error_keeps_transaction_and_uncancelled_error_rolls_back() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := indexed_db_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 globalThis.log=[];globalThis.opening=indexedDB.open("errors",1);
 opening.onupgradeneeded=()=>opening.result.createObjectStore("items");
 opening.onsuccess=()=>{globalThis.db=opening.result;const tx=db.transaction(["items"],"readwrite");const store=tx.objectStore("items");store.add("first","key");const duplicate=store.add("second","key");
 duplicate.onerror=event=>{log.push(event.isTrusted&&event.cancelable&&event.bubbles&&duplicate.error.name==="ConstraintError"&&duplicate.result===undefined?"handled":"bad");event.preventDefault();store.put("next","next");};
 tx.oncomplete=()=>log.push("complete");tx.onabort=()=>log.push("unexpected abort");};true
 ')! == 'true'
	deliver_indexed_db_binding_tasks()
	assert runtime.evaluate_host('JSON.stringify(log)')! == '["handled","complete"]'
	assert runtime.evaluate_host(r'
 const tx=db.transaction("items","readwrite"),store=tx.objectStore("items");store.put("rolled back","temporary");const duplicate=store.add("duplicate","key");duplicate.onerror=()=>log.push("error");tx.onabort=()=>log.push(tx.error.name);true
 ')! == 'true'
	deliver_indexed_db_binding_tasks()
	assert runtime.evaluate_host(r'
 const read=db.transaction("items").objectStore("items").get("temporary");read.onsuccess=()=>log.push(read.result===undefined?"absent":"bad");true
 ')! == 'true'
	deliver_indexed_db_binding_tasks()
	assert runtime.evaluate_host('JSON.stringify(log)')! == '["handled","complete","error","ConstraintError","absent"]'
}

fn test_indexed_db_request_events_capture_and_bubble_through_transaction_and_connection() {
	mut runtime, mut document := indexed_db_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.evaluate_host(r'
 globalThis.events=[];globalThis.opening=indexedDB.open("event-parents",1);
 opening.onupgradeneeded=()=>{
  const db=opening.result,tx=opening.transaction,store=db.createObjectStore("items"),first=store.add("a",1),duplicate=store.add("b",1);
  for(const [name,target] of [["db",db],["tx",tx],["first",first],["duplicate",duplicate]]){
   for(const type of ["success","error"]){
    target.addEventListener(type,e=>events.push("capture "+name+" "+type),true);
    target.addEventListener(type,e=>events.push("bubble "+name+" "+type));
   }
  }
  db.addEventListener("error",e=>e.preventDefault());
  tx.onabort=()=>events.push("unexpected abort");
 };
 opening.onsuccess=()=>events.push("open");true
 ')!
	deliver_indexed_db_binding_tasks()
	assert runtime.evaluate_host('JSON.stringify(events)')! == '["capture db success","capture tx success","capture first success","bubble first success","capture db error","capture tx error","capture duplicate error","bubble duplicate error","bubble tx error","bubble db error","open"]'
}

fn test_indexed_db_binding_brands_conversion_blocking_and_upgrade_abort() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := indexed_db_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	assert runtime.evaluate_host(r'
 let errors=0;for(const op of [()=>new IDBFactory(),()=>indexedDB.open(),()=>indexedDB.open("x",0),()=>indexedDB.open.call({},"x"),()=>Object.getOwnPropertyDescriptor(globalThis,"indexedDB").get.call({}),()=>Object.getOwnPropertyDescriptor(IDBRequest.prototype,"result").get.call({})]){try{op()}catch(e){if(e instanceof TypeError)errors++}}
 const event=new IDBVersionChangeEvent("test",{oldVersion:2,newVersion:3,bubbles:true});globalThis.log=[];globalThis.first=indexedDB.open("blocked",1);
 first.onupgradeneeded=()=>first.result.createObjectStore("items");first.onsuccess=()=>{globalThis.db=first.result;db.onversionchange=event=>log.push("change:"+event.newVersion);};
 errors===6&&indexedDB.cmp([1,"a"],[1,"b"])===-1&&event instanceof Event&&event.oldVersion===2&&event.newVersion===3&&event.bubbles&&!event.isTrusted;
 ')! == 'true'
	deliver_indexed_db_binding_tasks()
	assert runtime.evaluate_host(r'
 globalThis.second=indexedDB.open("blocked",2);second.onblocked=event=>{log.push("blocked:"+event.oldVersion);db.close();};second.onupgradeneeded=()=>{log.push("upgrade");second.result.createObjectStore("temporary");second.transaction.abort();};second.onerror=()=>log.push(second.error.name);true
 ')! == 'true'
	deliver_indexed_db_binding_tasks()
	assert runtime.evaluate_host('JSON.stringify(log)')! == '["change:2","blocked:1","upgrade","AbortError"]'
}

fn test_indexed_db_binding_values_outlive_temporary_allocation_and_promises_keep_transactions_active() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := indexed_db_fixture()!
	defer {
		runtime.close()
		document.finalize()
	}
	mut temporary := platform.begin_thread_scratch('IndexedDB caller')
	source := r'
 globalThis.log=[];globalThis.opening=indexedDB.open("temporary",1);
 function result(request){return new Promise((resolve,reject)=>{request.onsuccess=()=>resolve(request.result);request.onerror=()=>reject(request.error);});}
 opening.onupgradeneeded=()=>opening.result.createObjectStore("items",{keyPath:"id",autoIncrement:true});
 result(opening).then(async db=>{globalThis.db=db;const tx=db.transaction(new Set(["items"]),"readwrite",{durability:"strict"}),store=tx.objectStore("items");tx.oncomplete=()=>log.push("complete");
 const value={text:"Русский 😀",array:[1,true,null]};const key=await result(store.add(value));log.push(key);const read=await result(store.get(key));log.push(read.text,read.id,read.array.join(","),tx.durability);});true
 '.clone()
	temporary.leave()
	assert runtime.evaluate_host(source)! == 'true'
	temporary.finish()
	gc_collect()
	deliver_indexed_db_binding_tasks()
	assert runtime.evaluate_host('JSON.stringify(log)')! == '[1,"Русский 😀",1,"1,true,","strict","complete"]'
	assert runtime.evaluate_host(r'
 const store=db.transaction("items","readwrite").objectStore("items");const cloneErrors=[];const marker={};let same=false;
 for(const value of [()=>0,{nested:Symbol()},new Map(),1n,new Array(2),(()=>{const x={};x.self=x;return x})()]){try{store.put(value);cloneErrors.push("accepted");}catch(e){cloneErrors.push(e instanceof DOMException?e.name:e.constructor.name);}}
 try{store.put({get text(){throw marker}})}catch(e){same=e===marker}
 JSON.stringify({cloneErrors,same});
 ')! == '{"cloneErrors":["DataCloneError","DataCloneError","DataCloneError","DataCloneError","DataCloneError","DataCloneError"],"same":true}'
	deliver_indexed_db_binding_tasks()
}

fn test_indexed_db_binding_listener_exception_aborts_upgrade_and_close_finishes_pending_native_open() {
	$if !darwin && !linux {
		return
	}
	mut runtime, mut document := indexed_db_fixture()!
	assert runtime.evaluate_host(r'
 globalThis.log=[];globalThis.request=indexedDB.open("thrown",1);request.onupgradeneeded=()=>{request.result.createObjectStore("items");throw new Error("upgrade failed")};request.onerror=()=>log.push(request.error.name);true
 ')! == 'true'
	deliver_indexed_db_binding_tasks()
	assert runtime.evaluate_host('JSON.stringify(log)')! == '["AbortError"]'
	assert runtime.evaluate_host('globalThis.pending=indexedDB.open("closed",1);true')! == 'true'
	runtime.close()
	deliver_indexed_db_binding_tasks()
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut window := unsafe { &html.WindowModel(settings.global_object()) }
	mut scope := window.window_or_worker_global_scope()
	factory := scope.indexed_db()
	assert factory.database_infos().all(it.name !in ['thrown', 'closed'])
	document.finalize()
}
