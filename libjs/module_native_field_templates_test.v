module libjs

import os
import rand

fn test_module_templates_include_unexecuted_field_initializers_static_blocks_and_nested_classes() {
	directory := os.join_path(os.temp_dir(), 'vox-native-field-templates-' + rand.uuid_v4())
	defer { os.rmdir_all(directory) or {} }
	source := 'globalThis.effects=0;export function factory(key){class Holder{priority=7;#r={value:42};[key]=function(){return this.priority};nested=class{leaf=42};static value=(effects++,8);static{effects++}answer(){return this.#r.value}}return Holder}export function exercise(){const key=Symbol("branch"),Holder=factory(key),value=new Holder,nested=new value.nested;return effects===2&&Holder.value===8&&value.answer()===42&&nested.leaf===42&&value[key].name==="[branch]"&&value[key]()===7}'
	for visit in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.enable_native_code_cache(directory, if visit == 0 {
			'/usr/bin/clang'
		} else {
			'/usr/bin/false'
		})!
		mut module_record := SourceTextModule.parse(source, vm.realm(), 'native-fields.mjs', unsafe { nil })!
		module_record.link(mut vm)!
		assert module_record.evaluate(mut vm)!.promise.state == .fulfilled
		if visit == 0 {
			mut index := 0
			mut prepared := 0
			for {
				batch := module_record.prepare_native_function_templates(mut vm, index, 1)!
				assert batch.unsupported == 0 && batch.diagnostics.len == 0
				prepared += batch.prepared
				index = batch.next_index
				if batch.done { break }
			}
			assert prepared >= 10
			assert vm.global_object().get(mut vm, PropertyName.from_str('effects'))!.number == 0
			assert vm.flush_native_code_cache()!.pending_executables == 0
		} else {
			vm.diagnose_native_code(true)!
			exercise := module_record.export_value(mut vm, utf16_string('exercise'))!
			assert call(mut vm, exercise, js_undefined(), [])!.as_bool()
			activity := vm.diagnose_native_code(false)!
			stats := vm.flush_native_code_cache()!
			assert stats.cache_hits >= 10 && stats.cache_misses == 0
			assert stats.compiler_invocations == 0 && stats.pending_executables == 0 && stats.last_error == ''
			assert activity.entries > 0 && activity.fast_steps > 0
		}
		vm.close_native_code()!
	}
}
