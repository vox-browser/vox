module browserjs

import dom
import html
import page

fn test_shared_event_handler_conversion_retains_any_object_and_invokes_noncallable_as_undefined() {
	$if !darwin {
		return
	}
	owner := page.Page.create(1)!
	url := dom.URL{ value: 'https://legacy-event-handler.example.test/' }
	document := html.create_navigation_document_for_page(url, url.origin(), none, unsafe { &dom.Page(owner) })!
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	runtime.bind_scripting_environment(settings)!
	runtime.install_event_target_binding()!
	target := settings.global_object()
	runtime.evaluate_host(r'globalThis.legacyHandlerReads=0;globalThis.legacyHandlerObject={get handleEvent(){legacyHandlerReads++;throw "must not read handleEvent"},[Symbol.toPrimitive](){legacyHandlerReads++;throw "must not convert handler"}};globalThis.legacyHandlerProxy=new Proxy({},{get(){legacyHandlerReads++;throw "must not read proxy"},getPrototypeOf(){legacyHandlerReads++;throw "must not read prototype"}});0')!
	for expression in ['legacyHandlerObject', 'legacyHandlerProxy'] {
		value := runtime.evaluate_host_value(expression)!
		runtime.set_javascript_event_handler(target, 'play', value)!
		assert runtime.javascript_event_handler(target, 'play')! == value
		callback := target.event_handler_attribute('play') or { panic('missing retained legacy callback') }
		invoke := callback.handle_event_with_exception or { panic('missing actual callback invocation') }
		_ = runtime.take_document_state_dirty()
		checkpoint_count := settings.realm().microtask_checkpoint_count
		assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
		result := invoke(dom.Event.create('play', dom.EventInit{}), target)!
		assert result.is_undefined()
		assert !runtime.take_document_state_dirty()
		assert settings.realm().microtask_checkpoint_count == checkpoint_count
		assert settings.realm().script_execution_depth == 0 && settings.realm().callback_execution_depth == 0
		assert !runtime.libjs_vm().has_running_execution_context()
	}
	assert runtime.evaluate_host('legacyHandlerReads')! == '0'
	assert settings.realm().reported_exceptions.len == 0 && target.event_listener_list().len == 1
	for expression in ['null', 'undefined', 'false', '0', '"return false"', 'Symbol("handler")',
		'1n'] {
		runtime.set_javascript_event_handler(target, 'play', runtime.evaluate_host_value(expression)!)!
		assert C.JSValueIsNull(runtime.context, runtime.javascript_event_handler(target, 'play')!)
		assert target.event_handler_attribute('play') == none && target.event_listener_list().len == 0
	}
}
