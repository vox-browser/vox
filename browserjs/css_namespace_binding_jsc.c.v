@[has_globals]
module browserjs

import css
import platform

__global css_namespace_bindings_ = map[voidptr]bool{}

pub fn (mut runtime Runtime) install_css_namespace_binding() ! {
	entry := platform.enter_persistent()
	defer { platform.leave_persistent(entry) }
	runtime.require_javascript_value_context()!
	owner := voidptr(&runtime)
	if owner in css_namespace_bindings_ { return }
	operation := runtime.make_value_host_function(fn [owner] (_ voidptr, args []voidptr) !voidptr {
		mut runtime := unsafe { &Runtime(owner) }
		method := runtime.binding_dom_string(args[0])!
		first := runtime.binding_dom_string(args[1])!
		if method == 'escape' { return runtime.binding_string(css.escape(first)) }
		if method == 'supportsCondition' {
			return C.JSValueMakeBoolean(runtime.context, css.supports_condition(first))
		}
		second := runtime.binding_dom_string(args[2])!
		return C.JSValueMakeBoolean(runtime.context, css.supports_property(first, second))
	})!
	factory := runtime.evaluate_host_value(css_namespace_binding_factory())!
	defer { runtime.release_javascript_value(factory) }
	runtime.call_javascript_function(factory, C.JSValueMakeUndefined(runtime.context), [
		operation,
		C.JSContextGetGlobalObject(runtime.context),
	])!
	css_namespace_bindings_[owner] = true
	runtime.add_close_handler(fn [owner] () { css_namespace_bindings_.delete(owner) })
}
