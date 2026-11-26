// SPDX-License-Identifier: BSD-2-Clause
module libjs

import os
import rand

fn test_lazy_module_templates_compile_without_author_side_effects_and_cover_later_nested_calls() {
	directory := os.join_path(os.temp_dir(), 'vox-module-templates-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		})!
		mut module_record := SourceTextModule.parse('globalThis.effects=0;export function factory(){effects++;return function nested(){return 42}}', vm.realm(), 'lazy-templates.mjs', unsafe { nil })!
		module_record.link(mut vm)!
		assert module_record.evaluate(mut vm)!.promise.state == .fulfilled
		if visit == 0 {
			first := module_record.prepare_native_function_templates(mut vm, 0, 1)!
			assert !first.done && first.prepared == 1 && first.unsupported == 0
			last := module_record.prepare_native_function_templates(mut vm, first.next_index, 128)!
			assert last.done && last.prepared == 1 && last.unsupported == 0
			assert vm.global_object().get(mut vm, PropertyName.from_str('effects'))!.number == 0
			vm.flush_native_code_cache()!
		} else {
			factory := module_record.export_value(mut vm, utf16_string('factory'))!
			nested := call(mut vm, factory, js_undefined(), [])!
			assert call(mut vm, nested, js_undefined(), [])!.number == 42
			assert vm.global_object().get(mut vm, PropertyName.from_str('effects'))!.number == 1
			stats := vm.flush_native_code_cache()!
			assert stats.cache_hits >= 3 && stats.cache_misses == 0 && stats.compiler_invocations == 0 && stats.last_error == ''
		}
		vm.close_native_code()!
	}
}
