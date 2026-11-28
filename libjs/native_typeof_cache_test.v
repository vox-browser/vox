module libjs

import os
import rand

fn test_native_typeof_reuses_code_with_current_vm_string_cells_and_no_compiler() {
	set_native_primitive_ops_for_testing(true)
	cache := os.join_path(os.temp_dir(), 'vox-native-typeof-reopen-' + rand.uuid_v4())
	defer { os.rmdir_all(cache) or {} }
	mut previous := unsafe { &PrimitiveString(nil) }
	for index in 0 .. 2 {
		mut vm := VM.create()
		create_simple_execution_context(mut vm)
		vm.profile_native_code()!
		mut script := Script.parse('function kind(x){return typeof x}kind(42)', vm.realm(), 'native-typeof-reopen.js', unsafe { nil })!
		assert vm.run(mut script)!.as_string().str() == 'number'
		stats := vm.compile_native_code(cache, if index == 0 { '/usr/bin/clang' } else { '/usr/bin/false' }, 1)!
		assert stats.cache_hit == (index == 1)
		vm.diagnose_native_code(true)!
		result := vm.run(mut script)!.as_string()
		assert voidptr(result) == voidptr(vm.native_type_names[3])
		assert voidptr(result) != voidptr(previous)
		assert vm.heap_roots().contains(voidptr(result))
		assert vm.diagnose_native_code(false)!.fast_steps > 0
		previous = result
		vm.close_native_code()!
	}
}
