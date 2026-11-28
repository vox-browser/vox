module libjs

fn search_reads_eval(mut vm VM, source string, budget u64) !Value {
	mut script := Script.parse(source, vm.realm(), 'array-search.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: budget})
}

fn test_array_search_reads_keep_live_coercion_inherited_accessors_and_proxy_order() {
	mut logs := []string{}
	for enabled in [false, true] {
		set_array_search_reads_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		vm.diagnose_native_code(true)!
		assert search_reads_eval(mut vm, '[1,2,42].indexOf(42)===2&&[1,2].indexOf(3)===-1',100000)!.as_bool()
		assert (vm.diagnose_native_code(false)!.direct_array_search_reads > 0) == enabled
		assert search_reads_eval(mut vm, '
			var log="",a=[1,0],p={get 1(){log+="g";return 42}};Object.setPrototypeOf(a,p);
			var from={valueOf(){log+="v";delete a[1];return 0}};
			var inherited=Array.prototype.indexOf.call(a,42,from)===1&&log==="vg";
			var proxy=new Proxy([1,42],{has(t,k){log+="h"+k;return Reflect.has(t,k)},get(t,k,r){log+="r"+k;return Reflect.get(t,k,r)}});
			inherited&&Array.prototype.indexOf.call(proxy,42)===1&&Array.prototype.indexOf.call("ab","b")===1&&Array.prototype.indexOf.call(new Uint8Array([1,42]),42)===1
		',100000)!.as_bool()
		logs << vm.global_object().get(mut vm,PropertyName.from_str('log'))!.as_string().str()
		assert vm.interpreter_stack().depth() == 0
	}
	assert logs[0] == logs[1]
	set_array_search_reads_for_testing(true)
}

fn test_array_search_reads_charge_the_same_execution_budget_as_has_then_get() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for budget in 1 .. 100 {
		mut results := []string{}
		for enabled in [false, true] {
			set_array_search_reads_for_testing(enabled)
			value := search_reads_eval(mut vm, '[1,2,3,4].indexOf(4)',u64(budget)) or {
				assert is_throw_completion(err)
				results << (thrown_value(err).as_object().error_message() or { '' })
				continue
			}
			results << value.str()
		}
		assert results[0] == results[1], 'budget ${budget}'
		assert vm.interpreter_stack().depth() == 0
	}
	set_array_search_reads_for_testing(true)
}

fn test_array_callback_reads_observe_live_data_holes_accessors_and_proxy_traps() {
	defer { set_array_search_reads_for_testing(true) }
	for enabled in [false, true] {
		set_array_search_reads_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		vm.diagnose_native_code(true)!
		assert search_reads_eval(mut vm, '
			var trace="", a=[1,2,3], receiver={};
			Object.setPrototypeOf(a,{get 1(){trace+="g";return 4}});
			Array.prototype.forEach.call(a,function(v,i,source){
				if(this!==receiver||source!==a)throw 1;
				trace+=i+":"+v+";";
				if(i===0){delete a[1];a[2]=8;a[3]=16}
			},receiver);
			var dense=[1,undefined,3], visits=0;
			var mapped=dense.map(function(x){visits++;return x});
			trace==="0:1;g1:4;2:8;"&&visits===3&&Object.hasOwn(mapped,"1")
				&&mapped.reduce((sum,x)=>sum+(x||0),0)===4
		', 100000)!.as_bool()
		assert (vm.diagnose_native_code(false)!.direct_array_search_reads > 0) == enabled
		assert search_reads_eval(mut vm, '
			var log="", proxy=new Proxy([1,2],{
				has(t,k){log+="h"+k;return k!=="0"},
				get(t,k,r){log+="g"+k;return Reflect.get(t,k,r)}
			});
			Array.prototype.reduce.call(proxy,(sum,x)=>sum+x,0)===2
				&&log==="glengthh0h1g1"
		', 100000)!.as_bool()
	}
}
