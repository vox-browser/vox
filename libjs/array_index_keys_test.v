module libjs

fn test_numeric_array_keys_preserve_canonical_boundaries_without_truncation() {
	defer { set_numeric_array_keys_for_testing(true) }
	for enabled in [false, true] {
		set_numeric_array_keys_for_testing(enabled)
		for index in [u64(0), 1, 2147483648, 4294967294, 4294967295, 4294967296, 9007199254740991,
			u64(0xffffffffffffffff)] {
			key := array_index_key(index)
			assert key.equals(PropertyName.from_str(index.str()))
			assert key.str() == index.str()
			assert key.is_number() == (index < u64(0xffffffff))
		}
	}
}

fn test_numeric_array_keys_preserve_sparse_proxy_getters_and_large_array_like_indices() {
	defer { set_numeric_array_keys_for_testing(true) }
	for enabled in [false, true] {
		set_numeric_array_keys_for_testing(enabled)
		for source in [
			'var log="";var p=new Proxy({length:3,0:"a",2:"c"},{has(t,k){log+="h"+k;return Reflect.has(t,k)},get(t,k,r){if(typeof k!=="string")throw 1;log+="g"+k;return Reflect.get(t,k,r)}});Array.prototype.indexOf.call(p,"c")===2&&log==="glengthh0g0h1h2g2"',
			'var log="";var o={get length(){log+="L";return 2},get 0(){log+="0";return "a"},get 1(){log+="1";return "b"}};Array.prototype.join.call(o,"-")==="a-b"&&log==="L01"',
			'Array.prototype.indexOf.call({length:4294967297,4294967296:42},42,4294967296)===4294967296',
			'Array.prototype.indexOf.call({length:4294967296,4294967295:42},42,4294967295)===4294967295',
		] {
			mut vm := VM.create()
			create_simple_execution_context(mut vm)
			mut script := Script.parse(source, vm.realm(), 'numeric-keys.js', unsafe { nil })!
			assert vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })!.as_bool(), source
		}
	}
}

fn test_numeric_array_key_diagnostic_counts_fast_and_large_fallback_paths() {
	defer { set_numeric_array_keys_for_testing(true) }
	set_numeric_array_keys_for_testing(true)
	diagnose_array_index_keys_for_testing(true)
	assert array_index_key(42).is_number()
	assert array_index_key(4294967295).is_string()
	activity := diagnose_array_index_keys_for_testing(false)
	assert activity.numeric == 1 && activity.strings == 1
}
