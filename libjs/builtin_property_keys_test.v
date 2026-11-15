module libjs

fn builtin_key_eval(source string) !Value {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut script := Script.parse(source, vm.realm(), 'builtin-keys.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })
}

fn test_length_key_checks_match_string_number_symbol_and_utf16_identity() {
	for enabled in [false, true] {
		set_builtin_key_cache_for_testing(enabled)
		assert PropertyName.from_str('length').is_length_property()
		for key in [PropertyName.from_str('Length'), PropertyName.from_str('length\x00'),
			PropertyName.from_str('lеngth'), PropertyName.from_str(''), PropertyName.from_number(0),
			PropertyName.from_symbol(Symbol.create(utf16_string('length'), .unique))] {
			assert !key.is_length_property()
		}
	}
	set_builtin_key_cache_for_testing(true)
}

fn test_cached_length_keys_preserve_observable_getters_setters_and_proxy_traps() {
	for enabled in [false, true] {
		set_builtin_key_cache_for_testing(enabled)
		for source in [
			'var gets=0;var o={0:42,get length(){gets++;return 1}};Array.prototype.indexOf.call(o,42)===0&&gets===1',
			'var log="";var o={0:"x",get length(){log+="g";return 1},set length(n){log+="s"+n}};Array.prototype.push.call(o,"y");log==="gs2"&&o[1]==="y"',
			'var log="";var p=new Proxy([42],{get(t,k,r){log+=k+",";return Reflect.get(t,k,r)}});Array.prototype.join.call(p)==="42"&&log==="length,0,"',
			'var a=[1,2,3];a.length=1;Object.defineProperty(a,"length",{writable:false});a.length===1&&a[1]===undefined',
			'var a=[1];Object.defineProperty(a,"length",{value:3});a.length===3&&!(1 in a)',
			'"abc".length===3&&new String("abc").length===3',
		] {
			assert builtin_key_eval(source)!.as_bool(), source
		}
	}
	set_builtin_key_cache_for_testing(true)
}

fn test_builtin_key_diagnostic_proves_cached_reads_and_comparisons_execute() {
	for enabled in [false, true] {
		set_builtin_key_cache_for_testing(enabled)
		diagnose_builtin_keys_for_testing(true)
		assert builtin_key_eval('var a=[1,2];a.push(3);a.indexOf(2)===1&&a.join(",")==="1,2,3"')!.as_bool()
		activity := diagnose_builtin_keys_for_testing(false)
		if enabled {
			assert activity.cached > 0 && activity.ascii_compares > 0 && activity.legacy == 0
		} else {
			assert activity.legacy > 0 && activity.cached == 0 && activity.ascii_compares == 0
		}
	}
	set_builtin_key_cache_for_testing(true)
}
