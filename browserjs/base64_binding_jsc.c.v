@[has_globals]
module browserjs

import html
import webidl

__global base64_bindings_ = map[voidptr]bool{}

pub fn (mut runtime Runtime) install_base64_binding() ! {
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if base64_bindings_[owner] { return }
	settings := runtime.scripting_settings_ or { return error('Base64 requires its actual global settings') }
	scope := settings.universal_global_scope()
	runtime.install_dom_exception_binding()!
	operation := runtime.make_value_host_function(fn [owner, scope] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		return runtime.base64_operation(scope, args) or {
			if err is JavaScriptValueException { return err }
			message := err.msg()
			if message.starts_with('InvalidCharacterError:') {
				exception := webidl.dom_exception_value(webidl.DOMException.create('InvalidCharacterError', message['InvalidCharacterError:'.len..].trim_left(' ')))
				return runtime.actual_javascript_exception(runtime.javascript_dom_exception(exception)!)
			}
			return runtime.actual_javascript_exception(runtime.binding_exception_value(err))
		}
	})!
	factory := runtime.evaluate_host_value(base64_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	global := C.JSContextGetGlobalObject(runtime.context)
	_ = runtime.call_javascript_function(factory, global, [operation, global])!
	register_runtime_binding(mut base64_bindings_, owner, true)
	runtime.add_close_handler(fn [owner] () { unregister_runtime_binding(mut base64_bindings_, owner) })
}

fn (mut runtime Runtime) base64_operation(scope &html.UniversalGlobalScopeMixin, args []voidptr) !voidptr {
	if args.len != 2 { return error('Missing base64 operation or argument') }
	name := runtime.binding_dom_string(args[0])!
	text := runtime.binding_dom_utf16(args[1])!
	if text.code_units().any(it > 0xff) {
		return error(if name == 'btoa' {
			'InvalidCharacterError: Data contains characters outside U+0000 to U+00FF'
		} else {
			'InvalidCharacterError: Input is not valid base64 data'
		})
	}
	data := text.str()
	result := if name == 'btoa' { scope.btoa(data)! } else { scope.atob(data)! }
	return runtime.binding_string(result)
}
