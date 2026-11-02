module browserjs

import dom
import html
import webidl

@[heap]
struct NativeNavigationErrors {
mut:
	values []dom.JSValue
}

fn native_interception_owner() !(&dom.Document, &html.WindowModel, &html.Navigation) {
	mut document := dom.Document.create(dom.URL{ value: 'https://native-navigation.test/start' })
	document.set_origin(document.url.origin())
	document.set_is_initial_about_blank(false)
	document.populate_with_html_head_and_body()!
	window := html.WindowModel.create_top_level(document, none, 'native-interception')!
	mut navigation := unsafe { &html.Navigation(window.navigation()) }
	model := window.navigable_model()
	entry := model.active_session_history_entry() or { panic('actual active history entry') }
	navigation.initialize_the_navigation_api_entries_for_a_new_document(model.get_session_history_entries(),
		entry)
	return document, window, navigation
}

fn native_interception_context(document &dom.Document) webidl.PromiseContext {
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	return webidl.PromiseContext{
		realm_id:      u64(voidptr(settings.realm()))
		job_scheduler: fn [document] (job fn ()) {
			html.queue_a_microtask(document, job)
		}
	}
}

fn native_interception_converter(runtime &Runtime) JavaScriptWebIDLValueConverter {
	return fn [runtime] (value webidl.Value) !voidptr {
		if value.kind == .undefined { return C.vox_jsc_JSValueMakeUndefined(runtime.context) }
		return runtime.actual_webidl_value(value)
	}
}

fn install_native_interception_handler(navigation &html.Navigation, callback webidl.CallbackType) {
	navigation.set_onnavigate(&dom.CallbackType{
		handle_event: fn [callback] (base &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			mut event := unsafe { &html.NavigateEvent(base) }
			event.intercept(html.NavigationInterceptOptions{
				callback:    callback
				focus_reset: .manual
				scroll:      .manual
			}) or { panic(err) }
			return dom.js_undefined()
		}
	})
}

fn test_source_navigation_waits_for_actual_jsc_thenable_without_serialized_values() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	mut document, _, mut navigation := native_interception_owner()!
	defer {
		runtime.close()
		document.finalize()
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	function := runtime.evaluate_host_value('(function(){"use strict";globalThis.navigationReceiver=this;return {then(resolve){globalThis.navigationResolve=resolve}}})')!
	callback := runtime.webidl_promise_callback(function, native_interception_context(document),
		native_interception_converter(runtime))!
	install_native_interception_handler(navigation, callback)
	result := navigation.navigate('/thenable', html.NavigationNavigateOptions{ history: .push })
	assert document.url.serialize() == 'https://native-navigation.test/thenable'
	assert result.committed.state() == .fulfilled && result.finished.state() == .pending
	assert runtime.evaluate_host('navigationReceiver===undefined&&typeof navigationResolve==="function"')! == 'true'
	runtime.evaluate_host('navigationResolve(undefined)')!
	html.perform_a_microtask_checkpoint()
	assert result.finished.state() == .fulfilled
	assert navigation.ongoing_navigate_event() == none && navigation.transition() == none
}

fn test_source_navigation_jsc_promise_rejection_retains_actual_author_object_in_error_event() {
	$if !darwin {
		return
	}
	mut runtime := Runtime.create()
	mut document, _, mut navigation := native_interception_owner()!
	defer {
		runtime.close()
		document.finalize()
	}
	settings := unsafe { &html.EnvironmentSettingsObject(document.relevant_settings_object()) }
	runtime.bind_scripting_environment(settings)!
	function := runtime.evaluate_host_value('(function(){return new Promise((resolve,reject)=>{globalThis.navigationReject=reject})})')!
	callback := runtime.webidl_promise_callback(function, native_interception_context(document),
		native_interception_converter(runtime))!
	install_native_interception_handler(navigation, callback)
	observed := &NativeNavigationErrors{}
	navigation.set_onnavigateerror(&dom.CallbackType{
		handle_event: fn [observed] (base &dom.Event, _ ?&dom.EventTarget) dom.JSValue {
			assert base.interface_ == .error_event
			event := unsafe { &dom.ErrorEvent(base) }
			mut errors := unsafe { &NativeNavigationErrors(observed) }
			errors.values << event.error()
			return dom.js_undefined()
		}
	})
	result := navigation.navigate('/reject', html.NavigationNavigateOptions{ history: .replace })
	assert result.committed.state() == .fulfilled && result.finished.state() == .pending
	transition := navigation.transition() or { panic('actual source transition') }
	original := runtime.evaluate_host_value('globalThis.originalNavigationReason={marker:42};originalNavigationReason')!
	runtime.evaluate_host('navigationReject(originalNavigationReason)')!
	html.perform_a_microtask_checkpoint()
	assert result.finished.state() == .rejected && observed.values.len == 1
	assert runtime.actual_webidl_value(result.finished.result().as_webidl_value()!)! == original
	assert runtime.actual_webidl_value(transition.finished().result().as_webidl_value()!)! == original
	assert runtime.actual_webidl_value(observed.values[0].as_webidl_value()!)! == original
	assert navigation.ongoing_navigate_event() == none && navigation.transition() == none
}
