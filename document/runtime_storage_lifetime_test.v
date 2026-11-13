module main

import html
import platform

fn test_script_runtime_and_bindings_survive_the_initialization_frame_arena() {
	$if !darwin || !prealloc {
		return
	}
	mut document := html.parse_document('<!doctype html><body><p id="target">ready</p></body>')
	mut scratch := platform.new_arena('runtime initialization frame')
	entry := scratch.enter()
	mut runtime := create_browser_script_runtime(.javascriptcore)
	mut messages := []string{}
	run_document_javascript(document, 'https://runtime-storage.test/', [
		'globalThis.originalNavigator=navigator;globalThis.originalBody=document.body;',
	], runtime, mut messages)
	scratch.leave(entry)
	assert messages == []string{}, messages.join('\n')
	assert !scratch.contains(voidptr(runtime))
	scratch.release()
	// Exercise records captured by native callbacks after scratch is unmapped.
	assert runtime.evaluate_host('navigator===originalNavigator&&navigator.userAgent.length>0&&document.body===originalBody&&document.getElementById("target").textContent==="ready"')! == 'true'
	runtime.close()
	document.finalize()
}
