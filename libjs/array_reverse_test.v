// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn reverse_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-reverse.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:10000})
}

fn test_reverse_retains_holes_and_observable_get_set_order() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert reverse_eval(mut vm, 'var a=[1,,,4];a.reverse()===a&&a.length===4&&a[0]===4&&a[3]===1&&!(1 in a)&&!(2 in a)')!.as_bool()
	assert reverse_eval(mut vm, 'var order="",a={length:2,get 0(){order+="a";return 1},set 0(v){order+="c"+v},get 1(){order+="b";return 2},set 1(v){order+="d"+v}};Array.prototype.reverse.call(a)===a&&order==="abc2d1"')!.as_bool()
	assert reverse_eval(mut vm, 'var a=[1,,];a.reverse()===a&&!(0 in a)&&a[1]===1')!.as_bool()
}
