module browserjs

import dom
import html
import os

fn test_first100_hybrid_cases_in_native_shell() {
	$if !darwin { return }
	root := os.getenv('VOX_PINNED_WPT_ROOT')
	assert root != ''
	name := os.getenv('VOX_HYBRID_CASE')
	assert name != ''
	url := dom.URL{ value: 'https://crypto-hybrid-upstream.test/'+name+'.html' }
	mut runtime := Runtime.create()
	mut host := CryptoHost.create(&dom.Document{ url: url, origin_: url.origin() })!
	host.install(mut runtime)!
	runtime.install_text_encoder_binding()!
	runtime.install_base64_binding()!
	mut params := URLSearchParamsHost.create_for_settings(host.settings)!
	params.install(mut runtime)!
	mut urls := URLHost.create_for_settings(host.settings)!
	urls.install(mut runtime)!
	mut owner := host.settings.responsible_event_loop()
	pause := owner.pause()
	defer { owner.unpause(pause); runtime.close() }
	runtime.evaluate_host('globalThis.self=globalThis;globalThis.location=new URL("https://crypto-hybrid-upstream.test/'+name+'.html");globalThis.nativeWptResult=null;')!
	runtime.evaluate_host(os.read_file(os.join_path(root, 'resources/testharness.js'))!)!
	runtime.evaluate_host('setup({output:false,explicit_done:true});add_completion_callback((tests,status)=>{globalThis.nativeWptResult={harness:status.status,tests:tests.map(t=>({name:t.name,status:t.status,message:t.message}))}});')!
	for source in os.getenv('VOX_HYBRID_SCRIPTS').split(';') {
		runtime.evaluate_host(os.read_file(os.join_path(root, source))!)!
	}
	runtime.evaluate_host('done()')!
	for turn in 0 .. 100000 {
		mut queue := owner.task_queue()
		if task := queue.dequeue() { task.execute() }
		for _ in 0 .. 10000 {
			job := owner.dequeue_microtask() or { break }
			job.execute()
		}
		runtime.evaluate_host('void 0')!
		if runtime.evaluate_host('nativeWptResult!==null')! == 'true' { break }
		assert turn < 99999, 'upstream harness did not complete'
	}
	os.write_file(os.getenv('VOX_HYBRID_WPT_RESULT'), runtime.evaluate_host('JSON.stringify(nativeWptResult)')!)!
	result := runtime.evaluate_host('JSON.stringify({harness:nativeWptResult.harness,total:nativeWptResult.tests.length,failures:nativeWptResult.tests.filter(t=>t.status!==0)})')!
	println(result)
	assert runtime.evaluate_host('nativeWptResult.harness===0&&nativeWptResult.tests.length>0&&nativeWptResult.tests.every(t=>t.status===0)')! == 'true', result
}
