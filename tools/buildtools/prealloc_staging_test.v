module buildtools

import os

fn test_staging_an_already_staged_compiler_preserves_single_closure_hooks() ! {
	root := temporary(os.vtmp_dir(), 'vox-nested-runtime-')!
	defer { remove(root) or {} }
	vroot := join(root, 'compiler')
	write_changed(join(vroot, 'vlib/builtin/allocation.c.v'), 'module builtin\npub fn v_realloc(b &u8, n int) &u8 {\n new_ptr = malloc(n)\n\t\t\tC.memcpy(new_ptr, b, n)\n return new_ptr\n}\n')!
	write_changed(join(vroot, 'vlib/builtin/prealloc.c.v'), 'module builtin\nfn prealloc_realloc() {}\n')!
	write_changed(join(vroot, 'vlib/builtin/closure/closure.c.v'), 'module closure\nfn closure_init_body() {\n initialize()\n}\n')!
	write_changed(join(vroot, 'vlib/builtin/closure/closure_nix.c.v'), 'module closure\nfn closure_mtx_lock_platform() {\n lock()\n}\nfn closure_mtx_unlock_platform() {\n unlock()\n}\n')!
	write_changed(join(vroot, 'vlib/builtin/builtin.c.v'), fixed_index_source())!
	compiler := join(vroot, 'v')
	os.write_file(compiler, '#!/bin/sh\ndirname "$0"\n')!
	os.chmod(compiler, 0o755)!
	first := prepare_prealloc(compiler, join(root, 'cache'))!
	second := prepare_prealloc(join(first, 'compiler/v'), join(root, 'cache'))!
	for file in ['closure.c.v', 'closure_nix.c.v', 'closure_prealloc_metadata.c.v'] {
		assert read(join(first, 'builtin/closure', file))! == read(join(second, 'builtin/closure', file))!
	}
	// The bounds checks are replaced once and stay defined once when the
	// staged compiler is staged again.
	for runtime in [first, second] {
		builtin_c := read(join(runtime, 'builtin/builtin.c.v'))!
		fixed_index := read(join(runtime, 'builtin/fixed_index.c.v'))!
		for signature, _ in fixed_index_functions {
			assert builtin_c.count(signature + ' {') + fixed_index.count(signature + ' {') == 1
		}
	}
	staged := join(first, 'compiler/v')
	assert prepare_prealloc(staged, join(root, 'cache'))! == second
	os.write_file(compiler, '#!/bin/sh\nexit 1\n')!
	assert read(staged)! == '#!/bin/sh\ndirname "$0"\n'
}

fn test_closure_staging_rejects_partial_or_duplicated_hooks() ! {
	for body in [
		'closure_metadata_enter()\n initialize()'
		'closure_metadata_enter()\n closure_metadata_enter()\n initialize()\n closure_metadata_leave()\n closure_metadata_leave()'
	] {
		mut rejected := false
		wrap_function('fn closure_init_body() {\n' + body + '\n}', 'fn closure_init_body()',
			'\tclosure_metadata_enter()\n', '\tclosure_metadata_leave()\n') or { rejected = true }
		assert rejected
	}
}

fn test_staged_runtime_can_be_regenerated_after_the_cache_directory_moves() ! {
	root := temporary(os.vtmp_dir(), 'vox-runtime-move-')!
	defer { remove(root) or {} }
	vroot := join(root, 'compiler')
	write_changed(join(vroot, 'vlib/builtin/allocation.c.v'), 'module builtin\npub fn v_realloc(b &u8, n int) &u8 {\n new_ptr = malloc(n)\n\t\t\tC.memcpy(new_ptr, b, n)\n return new_ptr\n}\n')!
	write_changed(join(vroot, 'vlib/builtin/prealloc.c.v'), 'module builtin\nfn prealloc_realloc() {}\n')!
	write_changed(join(vroot, 'vlib/builtin/closure/closure.c.v'), 'module closure\nfn closure_init_body() {\n initialize()\n}\n')!
	compiler := join(vroot, 'v')
	os.write_file(compiler, '#!/bin/sh\ndirname "$0"\n')!
	os.chmod(compiler, 0o755)!
	first := prepare_prealloc(compiler, join(root, 'old-cache'))!
	os.rename(join(root, 'old-cache'), join(root, 'moved-cache'))!
	second := prepare_prealloc(compiler, join(root, 'moved-cache'))!
	assert os.file_name(first) != os.file_name(second)
	assert real(join(second, 'compiler/vlib/builtin')) == join(second, 'builtin')
	assert prepare_prealloc(compiler, join(root, 'moved-cache'))! == second
}

fn fixed_index_source() string {
	mut parts := ['module builtin\n\nfn before() {}\n']
	for _, original in fixed_index_functions {
		parts << '@[inline; markused]\n' + original + '\n'
	}
	parts << '@[inline; markused]\nfn v_fixed_index_ni(i int, len int) int {\n\treturn v_fixed_index(v_ni_index(i, len), len)\n}\n'
	return parts.join('\n')
}

// The bounds checks leave builtin.c.v only when all of them are V's known
// definitions; the replacement file then defines every one of them.
fn test_fixed_index_functions_are_replaced_only_when_unchanged() {
	source := fixed_index_source()
	stripped := without_fixed_index_functions(source) or { panic('known definitions') }
	for signature, _ in fixed_index_functions {
		assert !stripped.contains(signature)
	}
	assert stripped.contains('fn before() {}')
	assert stripped.contains('fn v_fixed_index_ni(i int, len int) int')
	assert stripped.count('@[inline; markused]') == 1
	replacement := read(join(root_dir(), 'tools/prealloc_runtime/fixed_index.c.v')) or { panic(err) }
	for signature, _ in fixed_index_functions {
		assert replacement.count(signature + ' {') == 1
	}
	changed := source.replace('i64(i).str() + \', len: \' +', 'i.str() + \', len: \' +')
	assert changed != source
	assert without_fixed_index_functions(changed) == none
	assert without_fixed_index_functions(source.replace('@[inline; markused]\nfn v_fixed_index_u64', 'fn v_fixed_index_u64')) == none
}
