// WebIDL/AbstractOperations.cpp synchronous callback invocation. Actual JSC
// call results stay values; this path performs no Promise Resolve or then access.
module browserjs

import webidl

pub fn (mut runtime Runtime) webidl_callback(function voidptr, convert JavaScriptWebIDLValueConverter) !webidl.CallbackType {
	runtime.require_javascript_value_context()!
	if !C.JSValueIsObject(runtime.context, function) || !C.JSObjectIsFunction(runtime.context, function) {
		return error('TypeError: WebIDL callback is not callable')
	}
	runtime.retain_javascript_value(function)!
	owner_handle := voidptr(&runtime)
	stored_settings := runtime.callback_settings()
	return webidl.CallbackType{
		callback: fn [owner_handle, function, convert, stored_settings] (receiver webidl.Value, arguments []webidl.Value) !webidl.Value {
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
			return owner.webidl_value(result)
		}
	}
}
