module buildtools

import os

fn test_font_cache_separates_compiler_identities_and_still_rejects_changed_files() ! {
	root := temporary(os.temp_dir(), 'vox-font-cache-')!
	defer { remove(root) or {} }
	previous := os.getenv_opt('VOX_BUILD_TOOLS_CACHE_ROOT')
	os.setenv('VOX_BUILD_TOOLS_CACHE_ROOT', join(root, 'cache'), true)
	defer {
		if value := previous { os.setenv('VOX_BUILD_TOOLS_CACHE_ROOT', value, true) }
		else { os.unsetenv('VOX_BUILD_TOOLS_CACHE_ROOT') }
	}
	vroot := join(root, 'compiler-root')
	write_changed(join(vroot, 'vlib/x/ttf/ttf.v'), "module ttf\npub fn (mut tf TTF_File) init() {\n tf.read_offset_tables()\n tf.read_cmap_table()\n}\nfn (mut tf TTF_File) read_offset_tables() {\n if tag != 'head' {\n assert tf.calc_checksum(tf.tables[tag].offset, tf.tables[tag].length) == tf.tables[tag].checksum\n }\n}\n")!
	mut compilers := []string{}
	for name in ['first-v', 'second-v'] {
		path := join(root, name)
		os.write_file(path, "#!/bin/sh\nprintf '%s\\n' " + quote(vroot) + '\n')!
		os.chmod(path, 0o755)!
		compilers << path
	}
	first := prepare_font(compilers[0])!
	second := prepare_font(compilers[1])!
	assert first != second
	assert read(join(first, 'x/ttf/vox_glyph_index_init.v'))! == read(join(second, 'x/ttf/vox_glyph_index_init.v'))!
	assert prepare_font(compilers[0])! == first
	assert prepare_font(compilers[1])! == second
	os.write_file(join(first, 'x/ttf/ttf.v'), 'changed staged font')!
	mut rejected := false
	prepare_font(compilers[0]) or {
		rejected = true
		assert err.msg().contains('Modified staged font file')
	}
	assert rejected
	assert prepare_font(compilers[1])! == second
}
