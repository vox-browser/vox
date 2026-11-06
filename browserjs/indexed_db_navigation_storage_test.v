module browserjs

import dom
import html
import indexeddb
import loader
import platform

fn indexed_db_navigation_runtime(path string) !(&Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.dom_url_parse('https://idb-navigation-storage.test/${path}', dom.url_about_blank(), 'UTF-8') or { return error('Invalid navigation fixture URL') }
	mut document := html.create_navigation_document(url, url.origin(), none)!
	document.enable_native_storage()
	mut allocations := document.enter_native_storage()
	html.parse_html_from_a_string(document, '<!doctype html><p>Navigation storage</p>')
	allocations.finish()
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_indexed_db_binding()!
	return runtime, document
}

fn indexed_db_navigation_tasks() {
	mut loop := html.main_thread_event_loop()
	mut queue := loop.task_queue()
	for _ in 0 .. 100 {
		// A browser frame can dispatch tasks and checkpoints from its scratch.
		mut frame := platform.begin_thread_scratch('IndexedDB navigation frame')
		loop.perform_a_microtask_checkpoint()
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool {
			return task.source() == .database_access
		}) or { frame.finish(); return }
		task.execute()
		frame.finish()
	}
	assert false, 'IndexedDB navigation tasks did not finish'
}

fn close_indexed_db_navigation_runtime(mut runtime Runtime, mut document dom.Document) {
	// Document replacement closes the realm before retiring its payload. The
	// connection list it leaves in shared database storage must survive too.
	mut frame := platform.begin_thread_scratch('IndexedDB navigation close')
	runtime.close()
	document.destroy_a_document_and_its_descendants()
	document.finalize()
	frame.finish()
	storage := document.native_storage()
	document.release_native_storage()
	// Parser end steps retain their payload until the next event-loop turn.
	mut loop := html.main_thread_event_loop()
	loop.process()
	$if prealloc { assert storage.arena.usage().used == 0 }
}

fn test_indexed_db_data_and_checkpoint_survive_native_document_replacement() {
	mut first, mut document := indexed_db_navigation_runtime('first')!
	mut allocations := document.enter_native_storage()
	assert first.evaluate_host(r'
	 globalThis.opening=indexedDB.open("navigation",1);
	 opening.onupgradeneeded=()=>{
	  const store=opening.result.createObjectStore("items");
	  store.createIndex("byText","text");
	  store.put({text:"before navigation",bytes:new Uint8Array([3,4]).buffer},"key");
	 };
	 opening.onsuccess=()=>{globalThis.db=opening.result;globalThis.ready=true};true
	')! == 'true'
	allocations.finish()
	indexed_db_navigation_tasks()
	assert first.evaluate_host('ready&&db.version===1')! == 'true'
	// Exercise synchronous mutations of shared records after the open task.
	allocations = document.enter_native_storage()
	assert first.evaluate_host(r'
	 const tx=db.transaction("items","readwrite");
	 tx.objectStore("items").put({text:"after open",bytes:new Uint8Array([7,8]).buffer},"later");true
	')! == 'true'
	allocations.finish()
	indexed_db_navigation_tasks()
	close_indexed_db_navigation_runtime(mut first, mut document)
	// This is the first post-navigation checkpoint that crashed after Pikabu.
	indexed_db_navigation_tasks()

	mut second, mut replacement := indexed_db_navigation_runtime('second')!
	defer { close_indexed_db_navigation_runtime(mut second, mut replacement) }
	assert second.evaluate_host(r'
	 globalThis.values=[];globalThis.upgraded=false;
	 const request=indexedDB.open("navigation",1);
	 request.onupgradeneeded=()=>{upgraded=true};
	 request.onsuccess=()=>{
	  globalThis.db=request.result;
	  const store=db.transaction("items").objectStore("items");
	  store.get("key").onsuccess=event=>values.push(event.target.result);
	  store.get("later").onsuccess=event=>values.push(event.target.result);
	 };true
	')! == 'true'
	indexed_db_navigation_tasks()
	result := second.evaluate_host(r'
	 JSON.stringify({upgraded,name:db.name,values:values.map(value=>({text:value.text,bytes:Array.from(new Uint8Array(value.bytes))}))})
	')!
	assert result == '{"upgraded":false,"name":"navigation","values":[{"text":"before navigation","bytes":[3,4]},{"text":"after open","bytes":[7,8]}]}'
	assert second.evaluate_host('db.transaction("items").objectStore("items").indexNames.contains("byText")')! == 'true'
	indexed_db_navigation_tasks()
	// Shared data remains, while the retired page's connection is removed.
	for _, database in indexeddb.idb_databases() {
		if database.name == 'navigation' {
			assert database.connections == 1
		}
	}
}
