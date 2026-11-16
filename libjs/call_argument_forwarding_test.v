module libjs

@[heap]
struct ForwardingKeeper {
mut:
	retained []Value
}
fn (_ &ForwardingKeeper) name_for_call_stack() Utf16String { return utf16_string('keeper') }
fn (_ &ForwardingKeeper) realm() ?&Realm { return none }
fn (mut keeper ForwardingKeeper) internal_call(mut vm VM, receiver Value, arguments []Value) !Value {
	keeper.retained = arguments
	return js_undefined()
}

@[heap]
struct ForwardingViews {
mut:
	views [][]Value
}

fn forwarding_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'forwarding.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_forwarded_call_arguments_keep_custom_retention_and_native_views_independent() {
	for enabled in [false, true] {
		set_call_argument_forwarding_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		mut keeper := &ForwardingKeeper{}
		mut object := Object.create(vm.realm(), vm.realm().function_prototype)
		object.callable = FunctionObject(keeper)
		mut views := &ForwardingViews{}
		capture := NativeFunction.create(mut vm, vm.realm(), vm.realm().function_prototype, fn [mut views] (mut vm VM) !Value {
			views.views << vm.running_execution_context().arguments()
			return vm.argument(0)
		}, 1, PropertyName.from_str('capture'), none)
		mut global := vm.global_object()
		global.define_direct_property(PropertyName.from_str('keeper'), Value.from_object(object), 7)
		global.define_direct_property(PropertyName.from_str('capture'), Value.from_object(capture.object), 7)
		vm.diagnose_native_code(true)!
		assert forwarding_eval(mut vm, 'keeper.call(null,42);capture.call(null,17);capture.call(null,99)')!.number == 99
		assert (vm.diagnose_native_code(false)!.forwarded_call_slices > 0) == enabled
		assert keeper.retained.len == 1 && keeper.retained[0].number == 42
		assert views.views.len == 2 && views.views[0][0].number == 17 && views.views[1][0].number == 99
		assert vm.interpreter_stack().depth() == 0
	}
	set_call_argument_forwarding_for_testing(true)
}

fn test_forwarded_calls_preserve_arguments_objects_large_calls_receivers_and_throws() {
	for enabled in [false, true] {
		set_call_argument_forwarding_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		assert forwarding_eval(mut vm, '
			function keep(x){return arguments}var saved=keep.call(null,41);
			function plus(a,b){return this.n+a+b}var sum=plus.call({n:1},saved[0],0);
			function big(a,b,c,d,e,f,g,h,i){return i}var large=big.call(null,1,2,3,4,5,6,7,8,9);
			function count(){return arguments.length}var empty=count.call()===0&&count.call(null)===0;
			var threw=false;try{(function(v){throw v}).call(null,43)}catch(e){threw=e===43}
			var held;var proxy=new Proxy(function(){},{apply(t,r,args){held=args;return args[0]}});var result=proxy.call(null,44);count.call(null,99);
			saved[0]===41&&sum===42&&large===9&&empty&&threw&&result===44&&held[0]===44
		')!.as_bool()
		assert vm.interpreter_stack().depth() == 0
	}
	set_call_argument_forwarding_for_testing(true)
}
