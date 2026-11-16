// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import dom
import html
import os

fn test_document_entries_allow_large_initialization_with_a_bounded_shared_budget() {
	previous := os.getenv_opt('VOX_LIBJS_NATIVE_CACHE')
	os.setenv('VOX_LIBJS_NATIVE_CACHE','0',true)
	defer { if value := previous { os.setenv('VOX_LIBJS_NATIVE_CACHE',value,true) } else { os.unsetenv('VOX_LIBJS_NATIVE_CACHE') } }
	address := dom.URL{value:'https://large-initialization.test/'}
	mut document := html.parse_navigation_document('<body></body>',address,address.origin(),none)!
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close(); document.finalize() }
	assert runtime.libjs_execution_limits().max_instructions == 1000000
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_libjs_document(document)!
	assert runtime.evaluate('var initialized=0;for(var index=0;index<150000;index++){initialized++}initialized')! == '150000'
	assert runtime.compiled_code_cache_audit().max_instructions_per_entry == 10000000
	assert !runtime.native_context_initialized() && !runtime.agent_vm.has_running_execution_context()
}

fn test_native_event_listener_uses_the_document_budget_when_entered_without_a_script() {
	previous := os.getenv_opt('VOX_LIBJS_NATIVE_CACHE')
	os.setenv('VOX_LIBJS_NATIVE_CACHE','0',true)
	defer { if value := previous { os.setenv('VOX_LIBJS_NATIVE_CACHE',value,true) } else { os.unsetenv('VOX_LIBJS_NATIVE_CACHE') } }
	address := dom.URL{value:'https://large-listener.test/'}
	mut document := html.parse_navigation_document('<body></body>',address,address.origin(),none)!
	mut runtime := Runtime.create_with_engine(.libjs)
	defer { runtime.close(); document.finalize() }
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	runtime.install_libjs_document(document)!
	runtime.evaluate('var initialized=0;document.body.addEventListener("initialize",()=>{for(var index=0;index<150000;index++)initialized++})')!
	mut body := document.body()?
	_ = body.dispatch_event(dom.Event.create('initialize',dom.EventInit{}))
	assert runtime.evaluate('initialized')! == '150000'
	assert runtime.take_libjs_messages().len==0&&!runtime.agent_vm.has_running_execution_context()
}
