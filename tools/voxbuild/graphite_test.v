module main

import os

fn test_graphite_bridge_commands_keep_private_libraries_and_exported_abi() {
	metal := graphite_bridge_command('/project with spaces', '/prepared skia', '/out/Metal.dylib', '26.0')
	assert metal[0] == 'clang++'
	assert '-mmacosx-version-min=26.0' in metal
	assert '/project with spaces/native_graphite_darwin.mm' in metal
	assert '-I/prepared skia' in metal
	assert '-Wl,-hidden-lskia' in metal && '-Wl,-hidden-lskcms' in metal
	assert '-Wl,-exported_symbol,_vox_graphite_canvas_present_deferred' in metal
	assert '-Wl,-exported_symbol,_vox_graphite_canvas_draw_shape_native_grid' in metal
	assert '-Wl,-exported_symbol,_vox_graphite_prepare_webp_icc_rgba' in metal
	assert metal[metal.len - 3..] == ['-Wl,-install_name,@rpath/libVoxGraphite.dylib', '-o',
		'/out/Metal.dylib']
	dawn := graphite_dawn_bridge_command('/project with spaces', '/prepared skia', '/dawn build', '/out/Dawn.dylib', '26.0')
	assert '-fno-rtti' in dawn && '-DNDEBUG' in dawn && '-DSK_DAWN' in dawn
	assert '-I/dawn build/gen/include' in dawn
	assert '-Wl,-hidden-lwebgpu_dawn' in dawn
	assert '-Wl,-exported_symbol,_vox_graphite_picture_supports_shared_typefaces' in dawn
	assert '-Wl,-exported_symbol,_vox_graphite_draw_picture_regions_with_backdrop_pixels' in dawn
	assert dawn[dawn.len - 3..] == ['-Wl,-install_name,@rpath/libVoxGraphiteDawn.dylib', '-o',
		'/out/Dawn.dylib']
	for command in [metal, dawn] {
		assert 'python3' !in command && 'gn' !in command && 'cmake' !in command && 'ninja' !in command
		mut exported := map[string]bool{}
		for argument in command {
			if argument.starts_with('-Wl,-exported_symbol,') {
				assert argument !in exported
				exported[argument] = true
			}
		}
		assert exported.len == if '-DSK_DAWN' in command { 9 } else { 56 }
	}
}

fn test_graphics_cache_validation_rejects_missing_or_modified_sources() {
	temporary := make_temp_directory(os.temp_dir(), 'vox-graphite-cache-test-')!
	defer { os.rmdir_all(temporary) or {} }
	if _ := graphite_archive(temporary) {
		assert false, 'Missing graphics dependencies must require explicit setup'
	} else {
		assert err.msg().contains('docs/MACOS_BUILD.md')
	}
	source := os.join_path(temporary, 'private-source')
	make_directory(source)!
	path := os.join_path(source, 'patch.cpp')
	os.write_file(path, 'authenticated patched source')!
	expected := {
		'patch.cpp': hash_file(path)!
	}
	graphite_validate_patches(source, expected)!
	os.write_file(path, 'unexpected partial patch')!
	if _ := graphite_validate_patches(source, expected) {
		assert false, 'Modified source must not be linked against the cached archive'
	} else {
		assert err.msg().contains('incompletely patched')
	}
	assert os.read_file(path)! == 'unexpected partial patch'
}
