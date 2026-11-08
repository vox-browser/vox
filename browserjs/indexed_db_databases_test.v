module browserjs

import dom
import html
import indexeddb
import loader

fn deliver_enumeration_tasks() {
	indexeddb.cleanup_indexed_database_transactions(voidptr(html.main_thread_event_loop()))
	mut queue := html.main_thread_event_loop().task_queue()
	for index in 0 .. 100 {
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .database_access
		}) or { break }
		task.execute()
		indexeddb.cleanup_indexed_database_transactions(voidptr(html.main_thread_event_loop()))
		assert index < 99
	}
}

fn test_databases_returns_native_committed_snapshots_and_rejects_forged_receivers() {
	$if !darwin && !linux { return }
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://idb-databases-binding.test/' }
	mut document := html.parse_navigation_document('<!doctype html>', address, address.origin(), none)!
	mut runtime := Runtime.create()
	defer { runtime.close(); document.finalize() }
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_indexed_db_binding()!
	assert runtime.evaluate_host(r'
 globalThis.checks=[];globalThis.rejections=0;const operation=IDBFactory.prototype.databases;
 checks.push(operation.name==="databases",operation.length===0);
 for(const value of [{},Object.create(IDBFactory.prototype),null]){const p=operation.call(value);checks.push(p instanceof Promise);p.catch(e=>{if(e instanceof TypeError)rejections++})}
 globalThis.snapshots=[];indexedDB.databases().then(value=>snapshots.push(value));
 const request=indexedDB.open("enumerated",1);request.onupgradeneeded=()=>{
  indexedDB.databases().then(value=>snapshots.push(value));
 };
 request.onsuccess=()=>{globalThis.db=request.result;indexedDB.databases().then(value=>snapshots.push(value));};true
 ')! == 'true'
	deliver_enumeration_tasks()
	assert runtime.evaluate_host('checks.every(Boolean)&&rejections===3&&snapshots.length===3&&snapshots[0].length===0&&snapshots[1].length===0&&snapshots[2].length===1&&snapshots[2][0].name==="enumerated"&&snapshots[2][0].version===1')! == 'true'
	assert runtime.evaluate_host(r'
 db.close();const upgradeRequest=indexedDB.open("enumerated",2);
 upgradeRequest.onupgradeneeded=()=>indexedDB.databases().then(value=>snapshots.push(value));
 upgradeRequest.onsuccess=()=>{upgradeRequest.result.close();indexedDB.databases().then(value=>snapshots.push(value));};true
 ')! == 'true'
	deliver_enumeration_tasks()
	assert runtime.evaluate_host('snapshots.length===5&&snapshots[3][0].version===1&&snapshots[4][0].version===2&&snapshots[2][0].version===1&&snapshots[3]!==snapshots[4]&&snapshots[3][0]!==snapshots[4][0]')! == 'true'
}
