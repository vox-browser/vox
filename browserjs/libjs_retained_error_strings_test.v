// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import libjs
import webidl

fn retained_error_fixture() !(&Runtime, &dom.Document, &html.WindowModel) {
	address := dom.URL{value: 'https://retained-error.test/'}
	mut document := html.parse_navigation_document('<body></body>', address, address.origin(), none)!
	window := html.WindowModel.create_top_level(document, none, 'retained errors')!
	mut runtime := Runtime.create_with_engine(.libjs)
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_libjs_document(document)!
	return runtime, document, window
}

fn test_reported_libjs_timer_error_converts_after_its_callback_context_has_left() {
	mut runtime, mut document, window := retained_error_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.evaluate('var conversions=0;var reason={toString(){conversions++;return "retained timer error"}};setTimeout(()=>{throw reason},1)')!
	mut scope := window.window_or_worker_global_scope()
	scope.run_all_timers()
	assert scope.reported_errors().len == 1
	assert !runtime.agent_vm.has_running_execution_context()
	assert scope.reported_errors()[0].to_string_value() == 'retained timer error'
	assert runtime.evaluate('conversions')! == '1'
	assert !runtime.agent_vm.has_running_execution_context()
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
	assert !runtime.native_context_initialized()
}

fn test_retained_libjs_error_conversion_preserves_author_throw_and_cleans_its_scope() {
	mut runtime, mut document, window := retained_error_fixture()!
	defer { runtime.close(); document.finalize() }
	runtime.evaluate('var sentinel={};var reason={toString(){throw sentinel}};setTimeout(()=>{throw reason},1)')!
	mut scope := window.window_or_worker_global_scope()
	scope.run_all_timers()
	assert scope.reported_errors().len == 1 && !runtime.agent_vm.has_running_execution_context()
	value := scope.reported_errors()[0].as_webidl_value()!
	webidl.to_string(value) or {
		assert libjs.is_throw_completion(err)
		mut vm := runtime.agent_vm
		sentinel := runtime.realm.global_object_record().get(mut vm, libjs.PropertyName.from_str('sentinel'))!
		assert libjs.thrown_value(err).is_object() && voidptr(libjs.thrown_value(err).as_object()) == voidptr(sentinel.as_object())
		assert !vm.has_running_execution_context()
		settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
		assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
		return
	}
	assert false, 'Expected the original author-thrown value'
}
