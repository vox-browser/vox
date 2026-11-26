// SPDX-License-Identifier: BSD-2-Clause
module libjs

fn text_intrinsics_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'string-text-intrinsics.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions:10000})
}

fn test_default_string_intrinsics_trim_pad_repeat_and_preserve_alias_identity() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert text_intrinsics_eval(mut vm, '" \\ufefftext\\n".trim()==="text"&&" x ".trimStart()==="x "&&" x ".trimEnd()===" x"&&"7".padStart(3,"0")==="007"&&"7".padEnd(3,"x")==="7xx"&&"ab".repeat(3)==="ababab"&&"a".concat("b",42)==="ab42"&&String.prototype.trimLeft===String.prototype.trimStart&&String.prototype.trimRight===String.prototype.trimEnd')!.as_bool()
}

fn test_default_string_intrinsics_use_utf16_and_unicode_normalization() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert text_intrinsics_eval(mut vm, '"abc".at(-1)==="c"&&"😀".codePointAt(0)===128512&&"\\ud800".isWellFormed()===false&&"\\ud800".toWellFormed()==="�"&&"😀".isWellFormed()&&"e\\u0301".normalize()==="é"')!.as_bool()
}

fn test_string_text_intrinsics_have_standard_descriptors_and_borrowed_receivers() {
	mut vm := VM.create(); create_simple_execution_context(mut vm)
	assert text_intrinsics_eval(mut vm, 'var d=Object.getOwnPropertyDescriptor(String.prototype,"trim"),n=0;for(var run of [()=>String.prototype.trim.call(null),()=>String.prototype.padStart.call(undefined,3),()=>"x".repeat(-1),()=>"x".normalize("BAD")])try{run()}catch(e){if(e instanceof TypeError||e instanceof RangeError)n++}n===4&&d.writable&&d.configurable&&!d.enumerable&&d.value.length===0&&String.prototype.padStart.call(7,3,"0")==="007"')!.as_bool()
}
