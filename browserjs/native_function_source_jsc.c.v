module browserjs

#include "@DIR/native_function_registry.h"

fn C.vox_install_platform_function_source(context voidptr, factory voidptr, exception &voidptr) bool

// Source snapshots live in a private, agent-wide weak registry. The public
// formatter is an engine native callback, including its exceptional path.
pub fn (mut runtime Runtime) install_platform_function_source(factory_source string) ! {
	if factory_source == '' { return }
	runtime.require_javascript_value_context()!
	factory := runtime.evaluate_host_value(factory_source)!
	defer { runtime.release_javascript_value(factory) }
	mut exception := unsafe { nil }
	if !C.vox_install_platform_function_source(runtime.context, factory, &exception) {
		if exception != unsafe { nil } { return runtime.actual_javascript_exception(exception) }
		return error('Could not initialize platform function source')
	}
}
