module browserjs

import dom
import html
import indexeddb
import loader

fn cursor_binding_fixture() !(&Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://idb-cursor-binding.test/' }
	document := html.parse_navigation_document('<!doctype html>', address, address.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_indexed_db_binding()!
	return runtime, document
}

fn deliver_cursor_binding_tasks() {
	loop := html.main_thread_event_loop()
	mut tasks := loop.task_queue()
	for turn in 0 .. 200 {
		indexeddb.cleanup_indexed_database_transactions(voidptr(loop))
		task := tasks.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .database_access }) or { break }
		task.execute()
		assert turn < 199
	}
}

fn test_cursor_binding_reuses_request_and_resets_author_visible_values_per_iteration() {
	$if !darwin && !linux { return }
	mut runtime, mut document := cursor_binding_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 globalThis.checks=[];globalThis.seen=[];globalThis.opening=indexedDB.open("cursor-values",1);
 opening.onupgradeneeded=()=>{const store=opening.result.createObjectStore("items");store.add({v:1},[1]);store.add({v:2},[2]);};
 opening.onsuccess=()=>{
  const db=opening.result,tx=db.transaction("items"),store=tx.objectStore("items"),request=store.openCursor();
  checks.push(request.readyState==="pending",request.source===store,request.transaction===tx);
  let previous=null,oldKey=null;
  request.onsuccess=()=>{
   const cursor=request.result;checks.push(request.readyState==="done",request.result===cursor);
   if(!cursor){checks.push(previous.key===undefined,previous.primaryKey===undefined,previous.value===undefined);db.close();return}
   checks.push(cursor instanceof IDBCursor,cursor instanceof IDBCursorWithValue,cursor.source===store,cursor.request===request,cursor.direction==="next",cursor.key===cursor.key,cursor.primaryKey===cursor.primaryKey,cursor.value===cursor.value);
   if(previous)checks.push(cursor===previous,cursor.key!==oldKey,oldKey.join()==="1,author");
   seen.push(cursor.key[0]);cursor.key.push("author");cursor.value.v=99;
   previous=cursor;oldKey=cursor.key;cursor.continue();checks.push(request.readyState==="pending",cursor.key===oldKey,cursor.value.v===99);
   try{request.result;checks.push(false)}catch(e){checks.push(e.name==="InvalidStateError")}
   try{cursor.continue();checks.push(false)}catch(e){checks.push(e.name==="InvalidStateError")}
   let touched=false;const key=[0];Object.defineProperty(key,"0",{get(){touched=true;return 0}});
   try{cursor.continue(key);checks.push(false)}catch(e){checks.push(e.name==="InvalidStateError",!touched)}
  };
 };true
 ')! == 'true'
	deliver_cursor_binding_tasks()
	assert runtime.evaluate_host('JSON.stringify(seen)')! == '[1,2]'
	assert runtime.evaluate_host('checks.length>30&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}

fn test_index_cursor_binding_exposes_compound_keys_and_key_only_prototype() {
	$if !darwin && !linux { return }
	mut runtime, mut document := cursor_binding_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 globalThis.checks=[];globalThis.opening=indexedDB.open("cursor-index",1);
 const rejects=(name,fn)=>{try{fn();return false}catch(e){return e.name===name}};
 checks.push(rejects("TypeError",()=>new IDBCursor()),rejects("TypeError",()=>new IDBCursorWithValue()),rejects("TypeError",()=>IDBCursor.prototype.continue.call({})));
 opening.onupgradeneeded=()=>{const store=opening.result.createObjectStore("items");store.createIndex("lookup",["a","b"]);store.add({a:1,b:2},[5]);store.add({a:1,b:2},[6]);};
 opening.onsuccess=()=>{
  const db=opening.result,tx=db.transaction("items"),store=tx.objectStore("items"),index=store.index("lookup");
  checks.push(rejects("TypeError",()=>index.openCursor(null,"invalid")),rejects("DataError",()=>index.openCursor({})),index.objectStore===store);
  const request=index.openKeyCursor(null,"prev");let count=0;
  request.onsuccess=()=>{
   const cursor=request.result;count++;
   checks.push(cursor instanceof IDBCursor,!(cursor instanceof IDBCursorWithValue),!("value" in cursor),cursor.source===index,cursor.request===request,cursor.key.join()==="1,2",cursor.primaryKey[0]===(count===1?6:5));
   if(count===1){
    checks.push(rejects("TypeError",()=>cursor.advance(0)),rejects("TypeError",()=>cursor.advance(4294967296)),rejects("TypeError",()=>cursor.advance(NaN)),rejects("TypeError",()=>Object.getOwnPropertyDescriptor(IDBCursorWithValue.prototype,"value").get.call(cursor)));
    cursor.continuePrimaryKey([1,2],[5]);
   }else db.close();
  };
 };true
 ')! == 'true'
	deliver_cursor_binding_tasks()
	assert runtime.evaluate_host('checks.length===24&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}
