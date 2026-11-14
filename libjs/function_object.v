module libjs

// The FunctionObject surface the VM relies on (LibJS/Runtime/FunctionObject.h)
// and the JobCallback record from LibJS/Runtime/JobCallback.{h,cpp}. Concrete
// ECMAScript functions use ECMAScriptFunction's checked bytecode frames;
// NativeFunction supplies native calls. Hosts may also implement this interface.

pub interface FunctionObject {
	name_for_call_stack() Utf16String
	realm() ?&Realm
mut:
	// 7.3.14 Call ( F, V [ , argumentsList ] ) dispatches to [[Call]].
	internal_call(mut vm VM, this_value Value, arguments []Value) !Value
}

// [[Construct]] is optional. Keeping it separate preserves callable host
// records and native methods that have no constructor internal method.
pub interface ConstructorFunction {
mut:
	internal_construct(mut vm VM, arguments []Value, new_target &Object) !&Object
}

// 9.5.1 JobCallback Records, https://tc39.es/ecma262/#sec-jobcallback-records
@[heap]
pub struct JobCallback {
pub mut:
	callback    FunctionObject // [[Callback]]
	custom_data voidptr        // [[HostDefined]]
}

pub fn JobCallback.create(callback FunctionObject, custom_data voidptr) &JobCallback {
	return &JobCallback{
		callback:    callback
		custom_data: custom_data
	}
}

// 9.5.2 HostMakeJobCallback ( callback ), https://tc39.es/ecma262/#sec-hostmakejobcallback
pub fn make_job_callback(callback FunctionObject) &JobCallback {
	// 1. Return the JobCallback Record { [[Callback]]: callback, [[HostDefined]]: empty }.
	return JobCallback.create(callback, unsafe { nil })
}

// 9.5.3 HostCallJobCallback ( jobCallback, V, argumentsList ), https://tc39.es/ecma262/#sec-hostcalljobcallback
pub fn call_job_callback(mut vm VM, mut job_callback JobCallback, this_value Value, arguments []Value) !Value {
	// 1. Assert: IsCallable(jobCallback.[[Callback]]) is true.
	// 2. Return ? Call(jobCallback.[[Callback]], V, argumentsList).
	return job_callback.callback.internal_call(mut vm, this_value, arguments)
}
