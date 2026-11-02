module browserjs

fn test_actual_native_function_surface_retains_callback_and_owner_cleanup() {
	$if !darwin { return }
	mut runtime := Runtime.create()
	defer { runtime.close() }
	owner_handle := voidptr(runtime)
	actual := runtime.make_native_value_host_function('sourceSize', 1, fn [owner_handle] (_ voidptr, arguments []voidptr) !voidptr {
		owner := unsafe { &Runtime(owner_handle) }
		if arguments.len > 0 { return arguments[0] }
		return C.vox_jsc_JSValueMakeUndefined(owner.context)
	})!
	runtime.define_value_host_function('__nativeSourceFunction', fn [actual] (_ voidptr, _ []voidptr) !voidptr { return actual })!
	assert runtime.evaluate_host(r'{const callback=__nativeSourceFunction();const name=Object.getOwnPropertyDescriptor(callback,"name"),length=Object.getOwnPropertyDescriptor(callback,"length");const value={};let illegal=false;try{new callback()}catch(error){illegal=error instanceof TypeError}Object.getPrototypeOf(callback)===Function.prototype&&typeof callback==="function"&&callback.name==="sourceSize"&&callback.length===1&&name.writable===false&&name.enumerable===false&&name.configurable===true&&length.writable===false&&length.enumerable===false&&length.configurable===true&&!Object.prototype.hasOwnProperty.call(callback,"prototype")&&Function.prototype.toString.call(callback).includes("[native code]")&&illegal&&callback(value)===value}')! == 'true'
	record := native_value_host_function_record(actual) or { panic('missing actual function record') }
	assert voidptr(record.runtime) == owner_handle
	mut other := Runtime.create()
	defer { other.close() }
	other_handle := voidptr(other)
	other_actual := other.make_native_value_host_function('other', 0, fn [other_handle] (_ voidptr, _ []voidptr) !voidptr {
		owner := unsafe { &Runtime(other_handle) }
		return C.vox_jsc_JSValueMakeNumber(owner.context, 7)
	})!
	assert voidptr((native_value_host_function_record(other_actual) or { panic('missing other record') }).runtime) == other_handle
	runtime.close()
	assert native_value_host_function_record(actual) == none
	assert native_value_host_function_record(other_actual) != none
	other.close()
	assert native_value_host_function_record(other_actual) == none
	if _ := runtime.make_native_value_host_function('closed', 0, fn (_ voidptr, _ []voidptr) !voidptr { assert false; return unsafe { nil } }) {
		assert false
	} else { assert err.msg().contains('closed') }
}
