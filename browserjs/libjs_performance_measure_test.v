// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import os
import rand

fn libjs_measure_fixture(cache string, compiler string) !(&Runtime, &dom.Document, &html.GlobalScopePerformance) {
	previous_cache := os.getenv_opt('VOX_LIBJS_NATIVE_CACHE')
	previous_compiler := os.getenv_opt('VOX_LIBJS_NATIVE_COMPILER')
	os.setenv('VOX_LIBJS_NATIVE_CACHE', cache, true)
	os.setenv('VOX_LIBJS_NATIVE_COMPILER', compiler, true)
	defer {
		if value := previous_cache { os.setenv('VOX_LIBJS_NATIVE_CACHE', value, true) } else { os.unsetenv('VOX_LIBJS_NATIVE_CACHE') }
		if value := previous_compiler { os.setenv('VOX_LIBJS_NATIVE_COMPILER', value, true) } else { os.unsetenv('VOX_LIBJS_NATIVE_COMPILER') }
	}
	address := dom.URL{value:'https://libjs-measure.test/'}
	mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create_with_engine(.libjs)
	runtime.bind_scripting_environment(settings)!
	runtime.install_libjs_document(document)!
	runtime.install_performance_binding()!
	mut scope := settings.window_or_worker_global_scope()!
	return runtime, document, scope.performance()
}

fn test_libjs_measure_uses_native_marks_timing_and_ordinary_detail_clone() {
	mut runtime, mut document, native := libjs_measure_fixture('0', '/usr/bin/false')!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate('performance.mark("a",{startTime:3});performance.mark("b",{startTime:8});var child={n:1},detail={a:child,b:child};detail.self=detail;var measure=performance.measure("span",{start:"a",end:"b",detail});child.n=9;var first=measure.detail,second=measure.detail;measure.name==="span"&&measure.entryType==="measure"&&measure.startTime===3&&measure.duration===5&&first!==detail&&first.a===first.b&&first.self===first&&first.a.n===1&&second!==first&&measure.toJSON().detail.a.n===1&&performance.getEntriesByType("measure")[0]===measure&&performance.measure("legacy","a","b").duration===5')! == 'true'
	assert native.get_entries_by_type('measure').len == 2
	assert native.get_entries_by_type('measure')[0].start_time == 3
	assert !runtime.native_context_initialized()
}

fn test_libjs_measure_dictionary_conversion_order_and_illegal_receiver() {
	mut runtime, mut document, _ := libjs_measure_fixture('0', '/usr/bin/false')!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate('var order="";var result=performance.measure({toString(){order+="n";return "ordered"}},{get detail(){order+="d";return null},get duration(){order+="u";return {valueOf(){order+="v";return 5}}},get end(){order+="e";return 8},get start(){order+="s"}});var converted=0,failed=false;try{performance.measure.call({},{toString(){converted++;return "bad"}})}catch(e){failed=e instanceof TypeError}order==="nduves"&&result.startTime===3&&result.duration===5&&result.detail===null&&failed&&converted===0&&performance.measure.length===1')! == 'true'
}

fn test_libjs_measure_does_not_publish_failed_clone_or_invalid_native_mark() {
	mut runtime, mut document, native := libjs_measure_fixture('0', '/usr/bin/false')!
	defer { runtime.close(); document.finalize() }
	assert runtime.evaluate('var failures=0,cloned=0;try{performance.measure("clone",{start:0,detail:()=>0})}catch(e){if(e instanceof DOMException&&e.name==="DataCloneError")failures++}try{performance.measure("missing",{start:"unknown mark",detail:{get value(){cloned++;return 1}}})}catch(e){if(e instanceof DOMException&&e.name==="SyntaxError")failures++}try{performance.measure("invalid",{start:0,end:3,duration:3})}catch(e){if(e instanceof TypeError)failures++}failures===3&&cloned===0&&performance.getEntriesByType("measure").length===0')! == 'true'
	assert native.get_entries_by_type('measure').len == 0
}

fn test_libjs_mark_clones_detail_and_measure_reopens_without_compilation() {
	directory := os.join_path(os.temp_dir(), 'vox-user-timing-cache-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut runtime, mut document, _ := libjs_measure_fixture(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		assert runtime.evaluate('var data={n:1};var mark=performance.mark("start",{startTime:3,detail:data});data.n=9;var measured=performance.measure("span",{start:"start",duration:5,detail:{devtools:{track:"React"}}});mark.detail.n===1&&measured.duration===5&&measured.detail.devtools.track==="React"')! == 'true'
		mut vm := runtime.agent_vm
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits > 0 && stats.cache_misses == 0 && stats.compiler_invocations == 0 }
		runtime.close()
		document.finalize()
	}
}
