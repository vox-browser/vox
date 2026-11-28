module libjs

import platform

fn test_regex_register_restore_keeps_snapshot_values_for_both_overlap_directions() {
	for case_ in [
		[0, 1, 10, 10, 20, 30, 50],
		[2, 0, 30, 40, 50, 40, 50],
	] {
		mut scratch := RegexVmScratch.new()
		scratch.register_pool = [i32(10), 20, 30, 40, 50]
		scratch.registers = unsafe { scratch.register_pool[case_[1]..case_[1] + 3] }
		mut vm := RegexVm{ program: &RegexProgram{}, input: RegexUtf16Input{}, scratch: scratch }
		vm.restore_registers(uint(case_[0]))
		assert scratch.register_pool == case_[2..].map(i32(it))
	}
}

fn test_regex_register_restore_does_not_retain_a_temporary_per_backtrack() {
	mut scratch := RegexVmScratch.new()
	scratch.registers = [i32(0), 0]
	scratch.register_pool = [i32(12), 34]
	mut vm := RegexVm{ program: &RegexProgram{}, input: RegexUtf16Input{}, scratch: scratch }
	vm.restore_registers(0)
	before := platform.thread_arena_usage().used
	for _ in 0 .. 100000 { vm.restore_registers(0) }
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 4096
	}
	assert scratch.registers == [i32(12), 34]
	assert scratch.register_pool == [i32(12), 34]
	mut empty := RegexVmScratch.new()
	empty.register_pool = [i32(7)]
	mut empty_vm := RegexVm{ program: &RegexProgram{}, input: RegexUtf16Input{}, scratch: empty }
	empty_vm.restore_registers(1)
	assert empty.registers.len == 0
}

fn test_regexp_borrowed_input_preserves_capture_ownership_reentry_and_conversion_order() {
	for source in [
		'var input="aab 😀 aba",r=/(?<first>a+)(b)/dg,first=r.exec(input);r.lastIndex=5;var second=r.exec(input);first[0]==="aab"&&first.groups.first==="aa"&&first.indices[0].join() === "0,3"&&second[0]==="ab"&&second.indices[0].join()==="7,9"&&first.input===input&&first[1]==="aa"',
		'var r=/(a+)(b)/g,seen=[];var result="aab ab".replace(r,function(m,a,b,pos,s){seen.push(m+":"+a+":"+b+":"+pos+":"+s);r.lastIndex=0;r.exec("aaab");return a.length});result==="2 1"&&seen.join("|")==="aab:aa:b:0:aab ab|ab:a:b:4:aab ab"',
		'var order="",r=/a/y;r.lastIndex={valueOf(){order+="l";return 1}};var result=r.exec({toString(){order+="s";return "ba"}});order==="sl"&&result[0]==="a"&&result.index===1&&r.lastIndex===2',
		'var text="\\ud800x\\udfff",r=/./gu,a=r.exec(text),b=r.exec(text),c=r.exec(text);a[0].charCodeAt(0)===0xd800&&b[0]==="x"&&c[0].charCodeAt(0)===0xdfff&&a.input===text',
	] {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		mut script := Script.parse(source, vm.realm(), 'regexp-storage.js', unsafe { nil })!
		assert vm.run_with_limits(mut script, ExecutionLimits{ max_instructions: 100000 })!.as_bool(), source
	}
}
