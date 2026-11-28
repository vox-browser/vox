module libjs

fn direct_accessor_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'direct-accessors.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 100000})
}

fn test_direct_accessors_keep_live_mutations_receivers_and_abrupt_completions() {
	for enabled in [false, true] {
		set_direct_accessor_dispatch_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		vm.diagnose_native_code(true)!
		assert direct_accessor_eval(mut vm, '
			var log="", p={get x(){log+="g";return this.n},set x(v){log+="s";this.n=v}},o=Object.create(p);
			o.n=41;o.x++;var first=o.n===42&&log==="gs"&&!Object.hasOwn(o,"x");
			Object.defineProperty(p,"x",{get(){delete this.n;Object.defineProperty(p,"x",{value:43,writable:true,configurable:true});return 44},configurable:true});
			var second=o.x===44&&o.x===43;o.x=45;
			var proxyLog="",r=new Proxy({},{getOwnPropertyDescriptor(t,k){proxyLog+="g";return Reflect.getOwnPropertyDescriptor(t,k)},defineProperty(t,k,d){proxyLog+="d";return Reflect.defineProperty(t,k,d)}});
			var third=Reflect.set(p,"x",46,r)&&r.x===46&&proxyLog==="gd"&&p.x===43;
			delete o.x;Object.defineProperty(p,"x",{set(v){throw v},configurable:true});var threw=false;try{o.x=47}catch(e){threw=e===47}
			Object.defineProperty(p,"x",{get(){throw 48},configurable:true});var got=false;try{o.x}catch(e){got=e===48}
			first&&second&&third&&threw&&got&&o.n===undefined
		')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		assert (activity.direct_accessor_gets > 0) == enabled
		assert (activity.direct_accessor_sets > 0) == enabled
		assert vm.interpreter_stack().depth() == 0
	}
	set_direct_accessor_dispatch_for_testing(true)
}

fn test_direct_ordinary_writes_preserve_attributes_readonly_and_exotic_storage() {
	for enabled in [false, true] {
		set_direct_accessor_dispatch_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		assert direct_accessor_eval(mut vm, '
			var o={};Object.defineProperty(o,"x",{value:1,writable:true});Object.preventExtensions(o);o.x=42;
			var d=Object.getOwnPropertyDescriptor(o,"x"),first=o.x===42&&!d.enumerable&&!d.configurable&&d.writable;
			Object.freeze(o);var second=!Reflect.set(o,"x",43)&&o.x===42;
			var only={get x(){return 44}};var third=!Reflect.set(only,"x",45)&&only.x===44;
			var a=[1,2];a.length=1;a[3]=46;
			function mapped(x){arguments[0]=47;return x}
			var typed=new Uint8Array(1);typed[0]=258;
			first&&second&&third&&a.length===4&&a[3]===46&&mapped(0)===47&&typed[0]===2&&!Reflect.set(Object("ab"),"0","x")
		')!.as_bool()
	}
	set_direct_accessor_dispatch_for_testing(true)
}
