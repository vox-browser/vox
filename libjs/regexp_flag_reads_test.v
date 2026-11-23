module libjs

import platform
import math.bits

fn regexp_flag_read_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'regexp-flag-reads.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 1000000 })
}

fn test_intrinsic_regexp_flags_preserve_real_flags_and_generic_get_order_and_truthiness() {
	for enabled in [false, true] {
		set_intrinsic_regexp_flags_for_testing(enabled)
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		for source in [
			'new RegExp("a","ysumigd").flags==="dgimsuy"&&new RegExp("a","v").flags==="v"&&/a/.flags===""',
			'var read=Object.getOwnPropertyDescriptor(RegExp.prototype,"flags").get;var log="",names=["hasIndices","global","ignoreCase","multiline","dotAll","unicode","unicodeSets","sticky"],o={};for(let i=0;i<names.length;i++)Object.defineProperty(o,names[i],{get(){log+=names[i]+";";return i===0?0:i===1?"":i===2?NaN:i===3?{}:i===4?"x":i===5?1:i===6?false:true}});read.call(o)==="msuy"&&log===names.join(";")+";"',
			'var r=/a/g,log="";Object.defineProperty(r,"global",{get(){log+="g";Object.defineProperty(r,"ignoreCase",{value:true});return true}});r.flags==="gi"&&log==="g"',
			'var log="",names=["hasIndices","global","ignoreCase","multiline","dotAll","unicode","unicodeSets","sticky"],r=/a/g,p=new Proxy(r,{get(t,k){log+=k+";";return Reflect.get(t,k,t)}});Object.getOwnPropertyDescriptor(RegExp.prototype,"flags").get.call(p)==="g"&&log===names.join(";")+";"',
			'var get=Object.getOwnPropertyDescriptor(RegExp.prototype,"global").get,r=/a/g;Object.defineProperty(r,"borrowed",{get});r.borrowed===true&&get.call(r)===true&&Object.getOwnPropertyDescriptor(RegExp.prototype,"global").get.name==="get global"&&get.length===0',
			'var get=Object.getOwnPropertyDescriptor(RegExp.prototype,"global").get,bad=0;for(var o of [{},Object.create(/a/g),new Proxy(/a/g,{})])try{get.call(o)}catch(e){if(e instanceof TypeError)bad++}bad===3&&get.call(RegExp.prototype)===undefined',
			'var marker={},same=false,r=/a/g;Object.defineProperty(r,"ignoreCase",{get(){throw marker}});try{r.flags}catch(e){same=e===marker}same',
			'var r=/a/gim,held=r.flags;for(var i=0;i<30;i++){/a/suy.flags;/a/v.flags}held==="gim"',
		] {
			assert regexp_flag_read_eval(mut vm, source)!.as_bool(), source
		}
		vm.profile_native_code()!
		vm.diagnose_native_code(true)!
		assert regexp_flag_read_eval(mut vm, '/a/g.flags==="g"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		assert (activity.regexp_flag_getter_reads > 0) == enabled
	}
	set_intrinsic_regexp_flags_for_testing(true)
}

fn test_regexp_flag_spellings_include_generic_incompatible_flag_combinations() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert regexp_flag_read_eval(mut vm, 'var read=Object.getOwnPropertyDescriptor(RegExp.prototype,"flags").get,names=["hasIndices","global","ignoreCase","multiline","dotAll","unicode","unicodeSets","sticky"];var a={},b={};for(var name of names){a[name]=true;b[name]=false}read.call(a)==="dgimsuvy"&&read.call(b)===""')!.as_bool()
	for mask in 0 .. 256 {
		spelling := regexp_flag_spellings[mask]
		assert spelling.len == bits.ones_count_32(u32(mask))
		mut previous := -1
		for character in spelling {
			position := 'dgimsuvy'.index_u8(character)
			assert position > previous
			assert mask & (1 << position) != 0
			previous = position
		}
	}
}

fn test_regexp_flag_fast_read_preserves_prototype_special_cases_and_stack_exhaustion() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	mut regex := regexp_flag_read_eval(mut vm, '/a/g')!.as_object()
	key := PropertyName.from_str('global')
	assert regex.get(mut vm, key)!.as_bool()
	mut realm := vm.realm()
	original := realm.regexp_prototype
	realm.regexp_prototype = regex
	assert regex.get(mut vm, key)!.is_undefined()
	realm.regexp_prototype = original
	mut stack := vm.interpreter_stack()
	limit := stack.limit
	stack.limit = stack.top_ + frame_size_in_bytes(0) - 1
	if _ := regex.get(mut vm, key) {
		assert false
	}
	stack.limit = limit
	assert regex.get(mut vm, key)!.as_bool()
}

fn test_regexp_flag_fast_reads_do_not_retain_per_read_keys_or_native_frames() {
	$if prealloc {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		regex := regexp_flag_read_eval(mut vm, '/a/gim')!.as_object()
		key := PropertyName.from_str('flags')
		for _ in 0 .. 10 {
			assert regex.get(mut vm, key)!.as_string().utf16.len() == 3
		}
		before := platform.thread_arena_usage().used
		for _ in 0 .. 10000 {
			assert regex.get(mut vm, key)!.as_string().utf16.len() == 3
		}
		assert platform.thread_arena_usage().used - before < 4096
	}
}
