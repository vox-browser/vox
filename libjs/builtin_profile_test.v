module libjs

fn test_builtin_profile_records_completed_calls_and_is_disabled_by_default() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	function := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype,
		fn (mut vm VM) !Value {
			return Value.from_string(vm.create_string(Utf16String{data: []u16{len: 8192, init: u16(65)}}))
		}, 0, PropertyName.from_str('profiled'), none)
	profile_builtin_calls_for_testing(false)
	call(mut vm, Value.from_object(function.object), js_undefined(), [])!
	assert profile_builtin_calls_for_testing(true).len == 0
	result := call(mut vm, Value.from_object(function.object), js_undefined(), [])!
	assert result.as_string().utf16.data.len == 8192
	samples := profile_builtin_calls_for_testing(false)
	assert samples.len == 1 && samples[0].name == 'profiled' && samples[0].calls == 1
	assert samples[0].inclusive_ns > 0
	$if prealloc { assert samples[0].retained_bytes >= 16384 }
	call(mut vm, Value.from_object(function.object), js_undefined(), [])!
	assert profile_builtin_calls_for_testing(false).len == 0
}
