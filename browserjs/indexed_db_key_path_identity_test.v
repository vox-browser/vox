module browserjs

import dom
import html
import indexeddb
import loader

fn key_path_identity_fixture() !(&Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	address := dom.URL{ value: 'https://idb-key-path-identity.test/' }
	document := html.parse_navigation_document('<!doctype html>', address, address.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_indexed_db_binding()!
	return runtime, document
}

fn deliver_key_path_identity_tasks() {
	loop := html.main_thread_event_loop()
	indexeddb.cleanup_indexed_database_transactions(voidptr(loop))
	mut tasks := loop.task_queue()
	for turn in 0 .. 100 {
		task := tasks.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .database_access
		}) or { break }
		task.execute()
		indexeddb.cleanup_indexed_database_transactions(voidptr(loop))
		assert turn < 99
	}
}

fn test_indexed_db_key_paths_keep_wrapper_identity_without_mutating_native_schema() {
	$if !darwin && !linux { return }
	mut runtime, mut document := key_path_identity_fixture()!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host(r'
 globalThis.checks=[];globalThis.request=indexedDB.open("paths",1);
 request.onupgradeneeded=()=>{
  const store=request.result.createObjectStore("compound",{keyPath:["a","b"]});
  const index=store.createIndex("lookup",["x","y"]);
  globalThis.nativePathStore=store;globalThis.nativePathIndex=index;
  globalThis.storePath=store.keyPath;globalThis.indexPath=index.keyPath;
  checks.push(Array.isArray(storePath),Array.isArray(indexPath),storePath===store.keyPath,indexPath===index.keyPath,storePath!==indexPath);
  storePath[0]="author";indexPath.push("extra");
  checks.push(store.keyPath===storePath,store.keyPath[0]==="author",index.keyPath===indexPath,index.keyPath.length===3);
 };
 request.onsuccess=()=>{const db=request.result,tx=db.transaction("compound"),first=tx.objectStore("compound"),again=tx.objectStore("compound"),other=db.transaction("compound").objectStore("compound");
  checks.push(first===again,first.keyPath===again.keyPath,first.keyPath!==storePath,first.keyPath!==other.keyPath,first.keyPath.join(",")==="a,b",other.keyPath.join(",")==="a,b");db.close();};true
 ')! == 'true'
	deliver_key_path_identity_tasks()
	assert runtime.evaluate_host('checks.length===15&&checks.every(Boolean)')! == 'true'
	binding := indexed_db_bindings_[voidptr(runtime)] or { panic('missing IndexedDB binding') }
	store := binding.entries[runtime.evaluate_host_value('nativePathStore')!] or { panic('missing store') }
	index := binding.entries[runtime.evaluate_host_value('nativePathIndex')!] or { panic('missing index') }
	assert store.store.key_path_value().items.map(it.text) == ['a', 'b']
	assert index.index.key_path_value()!.items.map(it.text) == ['x', 'y']
	gc_collect()
	assert runtime.evaluate_host('nativePathStore.keyPath===storePath&&nativePathIndex.keyPath===indexPath&&storePath[0]==="author"&&indexPath.length===3')! == 'true'
}
