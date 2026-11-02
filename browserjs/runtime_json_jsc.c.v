module browserjs

fn C.vox_jsc_JSValueMakeFromJSONString(context voidptr, text voidptr) voidptr

fn (mut runtime Runtime) initialize_javascript_core_host_from_json(factory_source string, json_text string) ! {
	runtime.require_javascript_value_context()!
	// Keep construction and invocation in one HTML script turn.
	runtime.prepare_html_script()
	defer { runtime.clean_up_html_script() }
	factory := runtime.evaluate_host_value(factory_source)!
	defer { runtime.release_javascript_value(factory) }
	text := js_source_string(json_text)
	if text == unsafe { nil } { return error('JavaScriptCore JSON string creation failed') }
	defer { C.JSStringRelease(text) }
	value := C.vox_jsc_JSValueMakeFromJSONString(runtime.context, text)
	if value == unsafe { nil } { return error('SyntaxError: Invalid host JSON data') }
	runtime.retain_javascript_value(value)!
	defer { runtime.release_javascript_value(value) }
	runtime.call_engine_function(factory, [value])!
}
