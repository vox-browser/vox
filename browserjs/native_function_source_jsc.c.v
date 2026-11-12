module browserjs

#include "native_function_registry.h"

fn C.vox_platform_function_registry(source voidptr, operations &voidptr) bool

// The installer receives private agent-wide weak registry operations. Neither
// the registry nor its functions are published as author-accessible globals.
pub fn (mut runtime Runtime) install_platform_function_source(factory_source string) ! {
	if factory_source == '' { return }
	runtime.require_javascript_value_context()!
	mut operations := unsafe { [2]voidptr{} }
	if !C.vox_platform_function_registry(runtime.context, &operations[0]) {
		return error('Could not initialize platform function identity registry')
	}
	factory := runtime.evaluate_host_value(factory_source)!
	defer { runtime.release_javascript_value(factory) }
	_ = runtime.call_javascript_function(factory, C.JSContextGetGlobalObject(runtime.context),
		[operations[0], operations[1]])!
}
