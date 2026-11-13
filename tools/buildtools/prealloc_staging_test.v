module buildtools

import os

fn test_staging_an_already_staged_compiler_preserves_single_closure_hooks() ! {
	root := temporary(os.temp_dir(), 'vox-nested-runtime-')!
	defer { remove(root) or {} }
	vroot := join(root, 'compiler')
	write_changed(join(vroot, 'vlib/builtin/allocation.c.v'), 'module builtin\npub fn v_realloc(b &u8, n int) &u8 {\n new_ptr = malloc(n)\n\t\t\tC.memcpy(new_ptr, b, n)\n return new_ptr\n}\n')!
	write_changed(join(vroot, 'vlib/builtin/prealloc.c.v'), 'module builtin\nfn prealloc_realloc() {}\n')!
	write_changed(join(vroot, 'vlib/builtin/closure/closure.c.v'), 'module closure\nfn closure_init_body() {\n initialize()\n}\n')!
	write_changed(join(vroot, 'vlib/builtin/closure/closure_nix.c.v'), 'module closure\nfn closure_mtx_lock_platform() {\n lock()\n}\nfn closure_mtx_unlock_platform() {\n unlock()\n}\n')!
	compiler := join(vroot, 'v')
	os.write_file(compiler, '#!/bin/sh\ndirname "$0"\n')!
	os.chmod(compiler, 0o755)!
	first := prepare_prealloc(compiler, join(root, 'cache'))!
	second := prepare_prealloc(join(first, 'compiler/v'), join(root, 'cache'))!
	for file in ['closure.c.v', 'closure_nix.c.v', 'closure_prealloc_metadata.c.v'] {
		assert read(join(first, 'builtin/closure', file))! == read(join(second, 'builtin/closure', file))!
	}
	assert prepare_prealloc(join(first, 'compiler/v'), join(root, 'cache'))! == second
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
