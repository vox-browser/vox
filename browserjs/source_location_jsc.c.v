module browserjs

import html

fn (mut runtime Runtime) install_source_location_provider(realm &html.ScriptingRealm) {
	owner := voidptr(&runtime)
	provider := fn [owner] () ?html.ScriptSourceLocation {
		runtime := unsafe { &Runtime(owner) }
		return runtime.capture_current_source_location()
	}
	runtime.own_closure(voidptr(provider))
	mut mutable_realm := unsafe { &html.ScriptingRealm(realm) }
	mutable_realm.current_source_location_ = provider
	runtime.add_close_handler(fn [realm] () {
		mut mutable_realm := unsafe { &html.ScriptingRealm(realm) }
		mutable_realm.current_source_location_ = none
	})
}

fn (runtime &Runtime) capture_current_source_location() ?html.ScriptSourceLocation {
	if runtime.closed || runtime.context == unsafe { nil } { return none }
	mut exception := unsafe { nil }
	object := C.vox_jsc_JSObjectMakeError(runtime.context,0,unsafe { nil },&exception)
	if exception != unsafe { nil } || object == unsafe { nil } { return none }
	C.JSValueProtect(runtime.context,object)
	defer { C.JSValueUnprotect(runtime.context,object) }
	stack_value := runtime.binding_property(object,'stack') or { return none }
	stack := runtime.binding_dom_string(stack_value) or { return none }
	return source_location_from_jsc_stack(stack)
}

fn source_location_from_jsc_stack(stack string) ?html.ScriptSourceLocation {
	for frame in stack.split_into_lines() {
		last := frame.last_index(':') or { continue }
		previous := frame[..last].last_index(':') or { continue }
		line_text := frame[previous+1..last]
		column_text := frame[last+1..]
		if line_text == '' || column_text == '' || !line_text.bytes().all(it >= `0` && it <= `9`)
			|| !column_text.bytes().all(it >= `0` && it <= `9`) { continue }
		prefix := frame[..previous]
		start := if at := prefix.last_index('@') { at+1 } else { 0 }
		address := prefix[start..]
		if !address.contains(':') { continue }
		return html.ScriptSourceLocation{url:address,line:line_text.u32(),column:column_text.u32()}
	}
	return none
}
