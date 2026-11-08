module browserjs

import dom
import html
import indexeddb
import loader
import os
import platform
import time

// Optional external-fixture integration check. The caller supplies the pinned
// upstream root and the original META script order; assertions stay upstream.
fn test_upstream_indexed_db_in_native_dedicated_worker() {
	root := os.getenv('VOX_PINNED_WPT_ROOT')
	if root == '' { return }
	name := os.getenv('VOX_IDB_CASE')
	assert name != ''
	if !loader.is_initialized() { loader.initialize() }
	url := dom.URL{value: 'https://idb-upstream.test/' + name + '.js'}
	mut document := html.parse_navigation_document('<!doctype html>', url, url.origin(), none)!
	outside := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }.serialize()
	mut realm := &html.ScriptingRealm{}
	scope := html.DedicatedWorkerGlobalScope.create(url, html.WorkerOptions{}, realm)
	environment := html.WorkerEnvironmentSettingsObject.setup(&scope.WorkerGlobalScope, mut realm, outside, 1)
	mut runtime := Runtime.create_for_worker()
	mut global := WorkerGlobalHost.create(environment)!
	global.install(mut runtime)!
	runtime.install_indexed_db_binding()!
	runtime.install_base64_binding()!
	runtime.install_text_encoder_binding()!
	mut params := URLSearchParamsHost.create_for_settings(environment.settings)!
	params.install(mut runtime)!
	mut urls := URLHost.create_for_settings(environment.settings)!
	urls.install(mut runtime)!
	mut timers := TimerHost.create_for_settings(environment.settings)!
	timers.install(mut runtime)!
	mut owner := environment.settings.responsible_event_loop()
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate_host('self instanceof DedicatedWorkerGlobalScope && typeof window === "undefined"')! == 'true'
	runtime.evaluate_host('globalThis.nativeWptResult=null;')!
	runtime.evaluate_host(os.read_file(os.join_path(root, 'resources/testharness.js'))!)!
	runtime.evaluate_host('setup({output:false,explicit_done:true});add_completion_callback((tests,status)=>{globalThis.nativeWptResult={harness:status.status,tests:tests.map(t=>({name:t.name,status:t.status,message:t.message}))}});')!
	for source in os.getenv('VOX_IDB_SCRIPTS').split(';') {
		runtime.evaluate_host(os.read_file(os.join_path(root, source))!)!
	}
	runtime.evaluate_host('done()')!
	deadline := time.now().add(30 * time.second)
	for {
		indexeddb.cleanup_indexed_database_transactions(voidptr(owner))
		mut queue := owner.task_queue()
		if task := queue.dequeue() { task.execute() } else { platform.pump_native_events(0.001) }
		for _ in 0 .. 10000 {
			job := owner.dequeue_microtask() or { break }
			job.execute()
		}
		runtime.evaluate_host('void 0')!
		global.take_outgoing()
		if runtime.evaluate_host('nativeWptResult!==null')! == 'true' { break }
		if time.now() > deadline {
			runtime.evaluate_host('timeout()')!
			break
		}
	}
	os.write_file(os.getenv('VOX_IDB_WPT_RESULT'), runtime.evaluate_host('JSON.stringify(nativeWptResult)')!)!
	result := runtime.evaluate_host('JSON.stringify({harness:nativeWptResult.harness,total:nativeWptResult.tests.length,failures:nativeWptResult.tests.filter(t=>t.status!==0)})')!
	println(result)
	assert runtime.evaluate_host('nativeWptResult.harness===0&&nativeWptResult.tests.length>0&&nativeWptResult.tests.every(t=>t.status===0)')! == 'true', result
}
