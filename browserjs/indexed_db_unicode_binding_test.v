module browserjs

import dom
import html
import indexeddb
import loader

fn indexed_db_unicode_fixture() !(&Runtime, &dom.Document) {
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{value: 'https://idb-unicode.test/'}
	document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	mut runtime := Runtime.create()
	runtime.bind_scripting_environment(unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) })!
	runtime.install_indexed_db_binding()!
	return runtime, document
}

fn drain_unicode_idb_tasks() {
	loop := html.main_thread_event_loop()
	mut queue := loop.task_queue()
	for _ in 0 .. 200 {
		indexeddb.cleanup_indexed_database_transactions(voidptr(loop))
		task := queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .database_access }) or { break }
		task.execute()
	}
}

fn test_indexed_db_preserves_raw_utf16_database_store_and_index_names() {
	mut runtime, mut document := indexed_db_unicode_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.evaluate_host(r'
 globalThis.checks=[];const name="db\0\ud800";
 globalThis.opening=indexedDB.open(name,1);
 opening.onupgradeneeded=()=>{
  const db=opening.result,names=["","\0","\ufffd","\ud800","\udc00","𝄞","水"].sort();
  for(const name of names){const store=db.createObjectStore(name);checks.push(store.name===name);const index=store.createIndex(name,"field");checks.push(index.name===name);index.name="\udc00\ud800";checks.push(index.name==="\udc00\ud800");}
  checks.push(JSON.stringify([...db.objectStoreNames])===JSON.stringify(names),db.name===name);
 };opening.onsuccess=()=>{checks.push(opening.result.name===name);opening.result.close()};true
 ')!
	drain_unicode_idb_tasks()
	assert runtime.evaluate_host('checks.length===24&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}

fn test_closed_connection_names_do_not_follow_a_later_upgrade() {
	mut runtime, mut document := indexed_db_unicode_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.evaluate_host(r'
 globalThis.ok=false;const first=indexedDB.open("closed-schema",1);
 first.onupgradeneeded=()=>first.result.createObjectStore("first");
 first.onsuccess=()=>{const old=first.result,names=old.objectStoreNames;old.close();const next=indexedDB.open(old.name,2);next.onupgradeneeded=()=>{next.result.createObjectStore("second");ok=JSON.stringify([...names])===JSON.stringify(["first"])&&next.result.objectStoreNames.length===2;};next.onsuccess=()=>next.result.close()};true
 ')!
	drain_unicode_idb_tasks()
	assert runtime.evaluate_host('ok')! == 'true'
}

fn test_indexed_db_clones_blob_and_file_bytes_metadata_and_strips_expandos() {
	mut runtime, mut document := indexed_db_unicode_fixture()!
	defer { runtime.close(); document.finalize() }
	settings := runtime.scripting_settings_ or { panic('missing settings') }
	mut streams := TransformStreamHost.create_for_settings(settings)!
	streams.install(mut runtime)!
	mut blobs := BlobHost.create_for_settings(settings)!
	blobs.install(mut runtime)!
	blobs.install_constructor()!
	mut files := FileHost.create_for_settings(settings)!
	files.install(mut runtime)!
	files.install_constructor()!
	runtime.evaluate_host(r'
 globalThis.checked=false;globalThis.checks=[];const opening=indexedDB.open("blob-records",1);
 opening.onupgradeneeded=()=>{
  const store=opening.result.createObjectStore("items"),blob=new Blob([new Uint8Array([5,6])],{type:"image/png"}),file=new File([new Uint8Array([0,255,7])],"\ud800\0.bin",{type:"application/octet-stream",lastModified:17});
  Object.defineProperty(blob,"expando",{enumerable:true,get(){throw new Error("Blob expando must not be cloned")}});
  store.put({blob,file},1);const read=store.get(1);
  read.onsuccess=()=>{const result=read.result;checks.push(result.blob instanceof Blob,result.file instanceof File,result.blob!==blob,result.file!==file,result.blob.type==="image/png",result.file.name===file.name,result.file.lastModified===17,result.blob.expando===undefined);
   Promise.all([result.blob.arrayBuffer(),result.file.arrayBuffer()]).then(([b,f])=>{checks.push(new Uint8Array(b).join() === "5,6",new Uint8Array(f).join() === "0,255,7");checked=true;});
  };
 };true
 ')!
	mut owner := settings.responsible_event_loop()
	for _ in 0 .. 1000 {
		indexeddb.cleanup_indexed_database_transactions(voidptr(owner))
		mut queue := owner.task_queue()
		if task := queue.dequeue() { task.execute() }
		for _ in 0 .. 1000 { job := owner.dequeue_microtask() or { break }; job.execute() }
		runtime.evaluate_host('void 0')!
		if runtime.evaluate_host('checked')! == 'true' { break }
	}
	assert runtime.evaluate_host('checked&&checks.length===10&&checks.every(Boolean)')! == 'true', runtime.evaluate_host('JSON.stringify(checks)')!
}
