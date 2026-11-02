module browserjs

import libjs

pub type NumberHostFunction = fn () f64

// Scalar native reads need no argument coercion, decimal formatting or string
// allocation. Keep the same runtime ownership and closed-context checks as the
// existing native-value host transport.
pub fn (mut runtime Runtime) define_number_host_function(name string, callback NumberHostFunction) ! {
	if runtime.closed { return error('JavaScript runtime is closed') }
	if runtime.engine == .libjs {
		mut vm := runtime.libjs_vm()
		realm := runtime.libjs_realm()
		native := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn [callback] (mut vm libjs.VM) !libjs.Value {
			return libjs.Value.from_f64(callback())
		}, 0, libjs.PropertyName.from_str(name), none)
		mut global := vm.get_global_object()
		global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(native.object), 0)
	} else {
		$if darwin || linux {
			context := runtime.context
			runtime.define_value_host_function(name, fn [context, callback] (_ voidptr, _ []voidptr) !voidptr {
				return C.vox_jsc_JSValueMakeNumber(context, callback())
			})!
			runtime.own_closure(voidptr(callback))
		} $else {
			return error('JavaScriptCore host bindings are unavailable on this platform')
		}
	}
}
