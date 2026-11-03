// Host binding boundary. Native functions execute the translated V records;
// JavaScriptCore remains the browser's execution engine until LibJS is complete.
module browserjs

import libjs
import platform

pub type HostFunction = fn (input string) !string
pub type TemporaryHostFunction = fn (input string) !HostFunctionReply

// Native string conversion copies the reply before retiring its workspace.
// Callbacks must leave the workspace before returning, and retain any DOM or
// host state they publish independently of these transport bytes.
// A callback which throws retires its workspace before propagating the error.
pub struct HostFunctionReply {
pub:
	value string
	workspace platform.ThreadScratchScope
}

fn (reply HostFunctionReply) finish() { reply.workspace.finish() }

@[heap]
struct HostFunctionRecord {
	callback HostFunction = unsafe { nil }
	temporary_callback TemporaryHostFunction = unsafe { nil }
}

fn (record &HostFunctionRecord) invoke(input string) !HostFunctionReply {
	if record.temporary_callback != unsafe { nil } { return record.temporary_callback(input) }
	return HostFunctionReply{value: record.callback(input)!}
}

pub fn (mut runtime Runtime) define_host_function(name string, callback HostFunction) ! {
	runtime.install_host_function(name, &HostFunctionRecord{callback: callback})!
}

pub fn (mut runtime Runtime) define_temporary_host_function(name string, callback TemporaryHostFunction) ! {
	runtime.install_host_function(name, &HostFunctionRecord{temporary_callback: callback})!
}

fn (mut runtime Runtime) install_host_function(name string, record &HostFunctionRecord) ! {
	if runtime.closed { return error('JavaScript runtime is closed') }
	if runtime.engine == .libjs {
		mut vm := runtime.libjs_vm()
		realm := runtime.libjs_realm()
		native := libjs.NativeFunction.create(mut vm, realm, realm.function_prototype, fn [record] (mut vm libjs.VM) !libjs.Value {
			input := vm.argument(0).to_primitive_string(mut vm)!
			output := record.invoke(input.str()) or {
				return libjs.throw_completion(libjs.Value.from_string(vm.create_string_from_str(err.msg())))
			}
			defer { output.finish() }
			return libjs.Value.from_string(vm.create_string_from_str(output.value))
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
