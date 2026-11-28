module main

import browserjs
import os
import x.json2

// Same-binary control: selector methods are host functions that call the
// JavaScript methods back, as before.
const retain_native_selector_hosts = os.getenv('VOX_RETAIN_NATIVE_SELECTOR_HOSTS') != ''

// Native DOM methods must be actual non-constructible engine functions. In
// addition to their WebIDL function surface, selector libraries use that
// surface when deciding whether to call the browser's selector implementation.
fn install_compact_native_selector_bindings(mut runtime browserjs.Runtime) ! {
	if runtime.engine != .javascriptcore { return }
	// A callable proxy without traps is such a function: it stringifies as
	// native code and takes its name, length, prototype and non-constructibility
	// from the method, while calls stay inside the engine instead of crossing
	// into a host function that calls the method back.
	if !retain_native_selector_hosts {
		// A plain function target is wrapped in a method first: methods have
		// no prototype property and cannot be constructed.
		runtime.evaluate_host('(function(){const apply=Reflect.apply;for(const owner of [document,Element.prototype]){for(const name of ["querySelector","querySelectorAll","matches","closest"]){if(owner===document&&(name==="matches"||name==="closest"))continue;let target=owner[name];if(Object.prototype.hasOwnProperty.call(target,"prototype")){const original=target;target={[name](selectors){return apply(original,this,arguments);}}[name];}Object.defineProperty(owner,name,{value:new Proxy(target,{}),writable:true,enumerable:true,configurable:true});}}Element.prototype.webkitMatchesSelector=Element.prototype.matches;})()')!
		return
	}
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
				return owner_runtime.forward_javascript_function(original, receiver, arguments)
			})!
			property := json2.encode(name)
			installer := runtime.retain_javascript_value(runtime.evaluate_host_value('(function(method){Object.defineProperty(${owner},${property},{value:method,writable:true,enumerable:true,configurable:true});})')!)!
			runtime.call_javascript_function(installer, undefined, [method])!
		}
	}
	runtime.evaluate_host('Element.prototype.webkitMatchesSelector=Element.prototype.matches;')!
}
