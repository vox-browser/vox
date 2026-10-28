// Host binding boundary. Native functions execute the translated V records;
// JavaScriptCore remains the browser's execution engine until LibJS is complete.
module browserjs

import libjs

pub type HostFunction = fn (input string) !string

@[heap]
struct HostFunctionRecord {
	@[required]
	callback HostFunction
}

pub fn (mut runtime Runtime) define_host_function(name string, callback HostFunction) ! {
	if runtime.closed { return error('JavaScript runtime is closed') }
	record := &HostFunctionRecord{ callback: callback }
	if runtime.engine == .libjs {
		mut vm := runtime.libjs_vm()
		realm := runtime.libjs_realm()
		native := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn [record] (mut vm libjs.VM) !libjs.Value {
			input := vm.argument(0).to_primitive_string(mut vm)!
			output := record.callback(input.str()) or {
				return libjs.throw_completion(libjs.Value.from_string(vm.create_string_from_str(err.msg())))
			}
			return libjs.Value.from_string(vm.create_string_from_str(output))
		}, 1, libjs.PropertyName.from_str(name), none)
		mut global := vm.get_global_object()
		global.define_direct_property(libjs.PropertyName.from_str(name), libjs.Value.from_object(native.object), 0)
	} else {
		$if darwin || linux {
			install_javascript_core_host_function(runtime.context, name, record)!
		} $else {
			return error('JavaScriptCore host bindings are available on macOS only')
		}
	}
	runtime.host_functions_ << record
}
