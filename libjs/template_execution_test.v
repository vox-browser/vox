// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn template_eval(mut vm VM, source string) !Value {
	mut script := Script.parse(source, vm.realm(), 'template.js', unsafe { nil })!
	return vm.run_with_limits(mut script, ExecutionLimits{max_instructions: 10000})!
}

fn test_template_interpolation_preserves_strings_code_units_and_primitive_types() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	for source in ['typeof `\${42}`==="string"&&`\${42}`==="42"', '`plain`==="plain"&&``===""', '`a\${null}\${undefined}\${true}\${42n}z`==="anullundefinedtrue42z"', '`\\ud800\${"\\udc00"}`.length===2&&`\\ud800\${"x"}`.charCodeAt(0)===55296', '`a\${`b\${2}c`}d`==="ab2cd"', '`line\\n\${42}\\t`==="line\\n42\\t"'] {
		assert template_eval(mut vm, source)!.as_bool()
	}
}

fn test_template_converts_each_substitution_with_string_hint_before_next_expression() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert template_eval(mut vm, 'var order="",a={toString:function(){order+="a";return "A"},valueOf:function(){throw 1}};function next(){order+="n";return "N"}var text=`x\${a}\${next()}z`;order==="an"&&text==="xANz"')!.as_bool()
	assert template_eval(mut vm, 'var hint="",o={};o[Symbol.toPrimitive]=function(h){hint=h;return 42};`\${o}`==="42"&&hint==="string"')!.as_bool()
	assert template_eval(mut vm, 'var saved=String;String=function(){throw 1};var text=`\${42}`;String=saved;text==="42"')!.as_bool()
}

fn test_template_abrupt_conversion_stops_later_substitutions_and_rejects_symbols() {
	mut vm := VM.create()
	create_simple_execution_context(mut vm)
	assert template_eval(mut vm, 'var touched=false,caught=false,o={toString:function(){throw 42}};try{`\${o}\${touched=true}`}catch(e){caught=e===42};caught&&!touched')!.as_bool()
	assert template_eval(mut vm, 'var touched=false,caught=false;try{`\${Symbol()}\${touched=true}`}catch(e){caught=e instanceof TypeError};caught&&!touched')!.as_bool()
}

fn test_template_conversion_reuses_native_code_in_a_fresh_vm_without_a_compiler() {
	directory := os.join_path(os.temp_dir(), 'vox-template-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 { '/usr/bin/clang' } else { '/usr/bin/false' })!
		vm.diagnose_native_code(true)!
		assert template_eval(mut vm, 'function f(x){return `live-region-\${x}`};f(42)==="live-region-42"')!.as_bool()
		activity := vm.diagnose_native_code(false)!
		stats := vm.flush_native_code_cache()!
		if visit == 1 { assert stats.cache_hits == 2 && stats.compiler_invocations == 0 && activity.entries >= 2 }
		vm.close_native_code()!
	}
}
