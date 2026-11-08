module browserjs

import dom
import html
import indexeddb
import loader

fn worker_indexed_db_fixture() !(&Runtime, &html.WorkerEnvironmentSettingsObject, &dom.Document) {
 if !loader.is_initialized() { loader.initialize() }
 url := dom.URL{value:'https://worker-indexed-db.test/worker.js'}
 document := html.parse_navigation_document('<!doctype html>',url,url.origin(),none)!
 outside := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }.serialize()
 mut realm := &html.ScriptingRealm{}
 scope := html.DedicatedWorkerGlobalScope.create(url,html.WorkerOptions{},realm)
 environment := html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope,mut realm,outside,1)
 mut runtime := Runtime.create_for_worker()
 mut global := WorkerGlobalHost.create(environment)!
 global.install(mut runtime)!
 runtime.install_indexed_db_binding()!
 return runtime,environment,document
}

fn drain_worker_indexed_db_tasks(environment &html.WorkerEnvironmentSettingsObject) {
 mut loop := environment.settings.responsible_event_loop()
 mut queue := loop.task_queue()
 for turn in 0 .. 200 {
  indexeddb.cleanup_indexed_database_transactions(voidptr(loop))
  if task := queue.take_first_runnable_matching(fn (task &html.Task) bool { return task.source() == .database_access }) { task.execute() }
  else { break }
  for _ in 0 .. 1000 { job := loop.dequeue_microtask() or { break }; job.execute() }
  assert turn < 199
 }
}

fn test_worker_indexed_db_uses_native_worker_factory_and_worker_task_queue() {
 mut runtime, environment, mut document := worker_indexed_db_fixture()!
 defer { runtime.close(); document.finalize() }
 assert environment.settings.responsible_document() == none
 assert runtime.evaluate_host(r'
 globalThis.checks=[];globalThis.opening=indexedDB.open("worker-binding",1);
 checks.push(indexedDB===indexedDB,indexedDB instanceof IDBFactory,typeof window==="undefined",opening.readyState==="pending");
 opening.onupgradeneeded=()=>{checks.push(opening.result instanceof IDBDatabase);const store=opening.result.createObjectStore("items");store.createIndex("lookup","field");store.add({field:"value"},1);};
 opening.onsuccess=()=>{const db=opening.result,tx=db.transaction("items"),store=tx.objectStore("items"),request=store.index("lookup").openCursor();request.onsuccess=()=>{const cursor=request.result;checks.push(cursor.key==="value",cursor.primaryKey===1,cursor.value.field==="value",cursor.source.objectStore===store);db.close();};};true
 ')! == 'true'
 drain_worker_indexed_db_tasks(environment)
 assert runtime.evaluate_host('checks.length===9&&checks.every(Boolean)')! == 'true',runtime.evaluate_host('JSON.stringify(checks)')!
}

fn test_worker_indexed_db_enumeration_and_global_brand() {
 mut runtime, environment, mut document := worker_indexed_db_fixture()!
 defer { runtime.close(); document.finalize() }
 assert runtime.evaluate_host(r'
 globalThis.brand=false;try{Object.getOwnPropertyDescriptor(globalThis,"indexedDB").get.call({})}catch(e){brand=e instanceof TypeError}
 globalThis.list=null;indexedDB.databases().then(value=>list=value);brand&&list===null
 ')! == 'true'
 drain_worker_indexed_db_tasks(environment)
 for _ in 0 .. 1000 { job := environment.settings.responsible_event_loop().dequeue_microtask() or { break }; job.execute() }
 assert runtime.evaluate_host('Array.isArray(list)')! == 'true'
}
