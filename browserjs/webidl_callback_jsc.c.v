// WebIDL/AbstractOperations.cpp synchronous callback invocation. Actual JSC
// call results stay values; this path performs no Promise Resolve or then access.
module browserjs

import webidl


pub fn (mut runtime Runtime) webidl_callback(function voidptr, convert JavaScriptWebIDLValueConverter) !webidl.CallbackType {
	return runtime.webidl_callback_with_result(function, convert, false)
}

// A void IDL callback discards its completion value. Projecting that value into
// WebIDL would root an otherwise unreachable return object until Runtime.close.
pub fn (mut runtime Runtime) webidl_void_callback(function voidptr, convert JavaScriptWebIDLValueConverter) !webidl.CallbackType {
	return runtime.webidl_callback_with_result(function, convert, true)
}

fn (mut runtime Runtime) webidl_callback_with_result(function voidptr, convert JavaScriptWebIDLValueConverter, discard_result bool) !webidl.CallbackType {
	runtime.require_javascript_value_context()!
	if !C.JSValueIsObject(runtime.context, function) || !C.JSObjectIsFunction(runtime.context, function) {
		return error('TypeError: WebIDL callback is not callable')
	}
	runtime.retain_javascript_value(function)!
	owner_handle := voidptr(&runtime)
	stored_settings := runtime.callback_settings()
	return webidl.CallbackType{
		callback: fn [owner_handle, function, convert, stored_settings, discard_result] (receiver webidl.Value, arguments []webidl.Value) !webidl.Value {
			mut owner := unsafe { &Runtime(owner_handle) }
			if owner.closed { return webidl.undefined_value() }
			owner.prepare_html_callback(stored_settings)
			defer { owner.clean_up_html_callback(stored_settings) }
			defer { owner.mark_document_state_dirty() }
			actual_this := convert(receiver)!
			mut actual_arguments := []voidptr{cap: arguments.len}
			for argument in arguments { actual_arguments << convert(argument)! }
			result := owner.call_javascript_function(function, actual_this, actual_arguments) or {
				if err is JavaScriptValueException {
					value := owner.webidl_value(err.value)!
					// Transfer the engine's abrupt-completion root to this value.
					owner.release_javascript_value(err.value)
					return webidl.throw_value(value)
				}
				return err
			}
			if discard_result { return webidl.undefined_value() }
			return owner.webidl_value(result)
		}
	}
}
