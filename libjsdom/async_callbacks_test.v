// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import html
import libjs
import os
import rand

fn native_async_eval(mut vm libjs.VM, source string) !libjs.Value {
	mut script := libjs.Script.parse(source, vm.realm(), 'native-async-callback.js', unsafe { nil })!
	return vm.run_with_limits(mut script, libjs.ExecutionLimits{max_instructions: 100000}) or { return error(exception_message(err)) }
}

fn test_cached_async_callback_awaits_real_native_animation_frame_then_mutates_template_contents() {
	directory := os.join_path(os.temp_dir(), 'vox-native-async-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	mut expected := 0
	for visit in 0 .. 2 {
		address := dom.URL{value: 'https://native-async.test/'}
		mut document := html.parse_navigation_document('<body><template id="t"><span id="loaded">ready</span></template></body>', address, address.origin(), none)!
		document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
		mut vm := libjs.VM.create()
		libjs.create_simple_execution_context(mut vm)
		mut host := Host.create(vm, vm.realm(), document, Hooks{})!
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert native_async_eval(mut vm, 'var time=0,finished=false;async function load(){time=await new Promise(requestAnimationFrame);document.body.appendChild(document.getElementById("t").content);finished=true;return document.getElementById("loaded").textContent}var text="";load().then(value=>text=value);!finished&&document.getElementById("loaded")===null')!.as_bool()
		mut window := host.frame_window(mut vm)!
		window.run_animation_frame_callbacks(42)
		parent := document.get_element_by_id('loaded')?.as_node().parent()?
		assert voidptr(parent) == voidptr(document.body()?.as_node())
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('finished'))!.as_bool()
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('time'))!.number == 42
		assert vm.global_object().get(mut vm, libjs.PropertyName.from_str('text'))!.as_string().str() == 'ready'
		assert vm.take_promise_job_errors().len == 0
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 0 { expected = stats.compiled_executables; assert expected >= 3 }
		else { assert stats.cache_hits == expected && stats.compiler_invocations == 0 && activity.entries > u64(expected) }
		vm.close_native_code()!
		host.close()
	}
}
