module main

import browserjs
import x.json2

// Native DOM methods must be actual non-constructible engine functions. In
// addition to their WebIDL function surface, selector libraries use that
// surface when deciding whether to call the browser's selector implementation.
fn install_compact_native_selector_bindings(mut runtime browserjs.Runtime) ! {
	if runtime.engine != .javascriptcore { return }
	owner_handle := voidptr(&runtime)
	undefined := runtime.evaluate_host_value('undefined')!
	for owner in ['document', 'Element.prototype'] {
		for name in ['querySelector', 'querySelectorAll', 'matches', 'closest'] {
			if owner == 'document' && name in ['matches', 'closest'] { continue }
			original := runtime.retain_javascript_value(runtime.evaluate_host_value('${owner}.${name}')!)!
			method := runtime.make_native_value_host_function(name, 1, fn [owner_handle, original] (receiver voidptr, arguments []voidptr) !voidptr {
				owner_runtime := unsafe { &browserjs.Runtime(owner_handle) }
				// Keep the existing receiver validation, single DOMString conversion,
				// mutation replay, selector scope and actual exception identity.
				return owner_runtime.call_javascript_function(original, receiver, arguments)
			})!
			property := json2.encode(name)
			installer := runtime.retain_javascript_value(runtime.evaluate_host_value('(function(method){Object.defineProperty(${owner},${property},{value:method,writable:true,enumerable:true,configurable:true});})')!)!
			runtime.call_javascript_function(installer, undefined, [method])!
		}
	}
	runtime.evaluate_host('Element.prototype.webkitMatchesSelector=Element.prototype.matches;')!
}
