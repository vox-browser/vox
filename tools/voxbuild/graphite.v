module main

import os

const graphite_skia_revision = '29ed1e87a0a50f3d8347e988842d9d59e7573efa'
const graphite_skia_sha512 = 'ba6e08942dcdd36a49f2a91d724c8e7be35d4ced30f259e3259ad1d3b24c4c140a3da1a1dd44170b985975fa5fca2871a147684e8f20ce7572bc334f3a024458'

// Upstream Skia/Dawn generators run only during explicit dependency setup.
// Normal browser builds validate those caches and compile these Vox bridges.
const graphite_exports = [
	'vox_graphite_draw_shadow_pixels',
	'vox_graphite_draw_image_pixels',
	'vox_graphite_draw_direct_image_pixels',
	'vox_graphite_draw_image_region_pixels',
	'vox_graphite_draw_image_regions_pixels',
	'vox_graphite_draw_image_tiles',
	'vox_graphite_resize_rgba_pixels',
	'vox_graphite_draw_shape_pixels',
	'vox_graphite_draw_shape_region_pixels',
	'vox_graphite_draw_shape_regions_pixels',
	'vox_graphite_draw_rounded_parts_pixels',
	'vox_graphite_draw_path_pixels',
	'vox_graphite_draw_dashed_path_pixels',
	'vox_graphite_draw_path_region_pixels',
	'vox_graphite_draw_shadow_region_pixels',
	'vox_graphite_draw_path_parts_pixels',
	'vox_graphite_draw_path_batch_pixels',
	'vox_graphite_draw_svg_image_pixels',
	'vox_graphite_draw_svg_image_region_pixels',
	'vox_graphite_draw_svg_pattern_pixels',
	'vox_graphite_prepare_webp_icc_rgba',
	'vox_graphite_supports_yuv422',
	'vox_graphite_release_unused_graphics_memory',
	'vox_graphite_release_idle_graphics_memory',
	'vox_graphite_retire_graphics_context',
	'vox_graphite_finish_frame',
	'vox_graphite_canvas_begin',
	'vox_graphite_canvas_begin_native_grid',
	'vox_graphite_canvas_upload',
	'vox_graphite_canvas_upload_queued',
	'vox_graphite_set_image_immutable_source',
	'vox_graphite_canvas_push_layer',
	'vox_graphite_canvas_pop_layer',
	'vox_graphite_canvas_draw_shadow',
	'vox_graphite_canvas_draw_shape',
	'vox_graphite_canvas_read',
	'vox_graphite_canvas_read_direct',
	'vox_graphite_canvas_read_iosurface',
	'vox_graphite_canvas_present',
	'vox_graphite_canvas_wait_present',
	'vox_graphite_canvas_present_deferred',
	'vox_graphite_canvas_schedule_present',
	'vox_graphite_canvas_release_present',
	'vox_graphite_canvas_draw_pixels',
	'vox_graphite_canvas_draw_cached_pixels',
	'vox_graphite_canvas_draw_layer_pixels',
	'vox_graphite_canvas_draw_mask',
	'vox_graphite_canvas_copy_pixels',
	'vox_graphite_canvas_draw_path',
	'vox_graphite_canvas_draw_image',
	'vox_graphite_canvas_draw_image_msaa',
	'vox_graphite_canvas_draw_shape_msaa',
	'vox_graphite_canvas_draw_shape_native_grid',
	'vox_graphite_canvas_draw_shape_isolated',
	'vox_graphite_canvas_draw_picture',
	'vox_graphite_canvas_end',
]

const graphite_dawn_exports = [
	'vox_graphite_picture_supports_shared_pixels',
	'vox_graphite_picture_supports_shared_typefaces',
	'vox_graphite_draw_picture_pixels',
	'vox_graphite_draw_picture_region_pixels',
	'vox_graphite_draw_picture_regions_pixels',
	'vox_graphite_draw_picture_regions_with_backdrop_pixels',
	'vox_graphite_picture_release_unused_graphics_memory',
	'vox_graphite_picture_release_idle_graphics_memory',
	'vox_graphite_picture_retire_graphics_context',
]

fn graphite_missing_dependency(path string) IError {
	return error('Missing prepared graphics dependency: ${path}. Complete the explicit native dependency setup in docs/MACOS_BUILD.md before building Vox.')
}

fn graphite_require_file(path string) ! {
	if !os.is_file(path) { return graphite_missing_dependency(path) }
}

fn graphite_validate_patches(source string, expected map[string]string) ! {
	for name, digest in expected {
		path := os.join_path(source, name)
		graphite_require_file(path)!
		if hash_file(path)! != digest {
			return error('Unexpected or incompletely patched graphics dependency: ${path}. Rebuild the prepared dependencies using docs/MACOS_BUILD.md; the browser build does not modify upstream sources.')
		}
	}
}

fn graphite_archive(repo string) !string {
	archive := os.join_path(repo, 'Build/deps/skia-brave', graphite_skia_revision + '.tar.gz')
	graphite_require_file(archive)!
	check_archive_digest(archive, graphite_skia_sha512, 'sha512')!
	return archive
}

fn graphite_deployment_target(repo string) !string {
	if target := os.getenv_opt('MACOSX_DEPLOYMENT_TARGET') {
		if target != '' { return target }
	}
	target := capture_command(['plutil', '-extract', 'LSMinimumSystemVersion', 'raw', '-o', '-',
		os.join_path(repo, 'packaging/Info.plist')])!.trim_space()
	if target == '' { return error('Info.plist has no LSMinimumSystemVersion') }
	return target
}

fn graphite_bridge_command(repo string, source string, output string, minimum string) []string {
	mut command := ['clang++', '-std=c++20', '-O2', '-fPIC', '-dynamiclib', '-fvisibility=hidden',
		'-fvisibility-inlines-hidden', '-mmacosx-version-min=' + minimum, '-DSK_GRAPHITE',
		'-DSK_GRAPHITE_USE_LEGACY_RRECT_CLIP_SHADER', '-I' + source,
		os.join_path(repo, 'native_graphite_darwin.mm'), '-L' + os.join_path(source, 'out/Release'),
		'-Wl,-hidden-lskia', '-Wl,-hidden-lskcms']
	for framework in ['Metal', 'CoreGraphics', 'Foundation', 'ImageIO', 'IOSurface'] {
		command << ['-framework', framework]
	}
	for symbol in graphite_exports { command << '-Wl,-exported_symbol,_' + symbol }
	command << ['-Wl,-install_name,@rpath/libVoxGraphite.dylib', '-o', output]
	return command
}

fn build_graphite(repo string, args []string) ! {
	$if !macos {
		return error('This backend requires macOS')
	}
	output := os.abs_path(required_option(args, '--output')!)
	// Keep the entrypoint compatible; GN uses this SDK only during dependency setup.
	required_option(args, '--skia-root')!
	graphite_archive(repo)!
	source := os.join_path(repo, 'Build/deps/skia-brave/source')
	stamp := os.join_path(source, '.vox-revision')
	graphite_require_file(stamp)!
	if os.read_file(stamp)!.trim_space() != graphite_skia_revision {
		return error('Unrecognized Skia source tree: ${source}. See docs/MACOS_BUILD.md.')
	}
	graphite_validate_patches(source, {
		'src/gpu/graphite/UniformManager.h':        '1570dc4bb9152b1325ebd6c805e42da2b957a19cb6221dece487df486b05cfe6'
		'src/sksl/SkSLMemoryLayout.h':              'fa91fe6d9e448e04c136fc0756710105bfe9e91c880a67d07ca6f79da0a10a72'
		'src/gpu/graphite/mtl/MtlGraphiteUtils.mm': 'f8e0e89321a5877e35e5ef7a9427299c91cd5a1999c40a64fc06025e13a00ec7'
		'src/gpu/graphite/BufferManager.cpp':       '91bd83a86b06e0930b2d09895650946b2e3f5513c9b97f229a1b6df89f59fbc6'
	})!
	for name in ['libskia.a', 'libskcms.a'] {
		graphite_require_file(os.join_path(source, 'out/Release', name))!
	}
	machine := capture_command(['uname', '-m'])!.trim_space()
	if machine !in ['arm64', 'x86_64'] {
		return error('Unsupported macOS architecture: ${machine}')
	}
	make_directory(os.dir(output))!
	run_command(graphite_bridge_command(repo, source, output, graphite_deployment_target(repo)!))!
	println('Built isolated Skia Metal backend: ${output}')
}

fn graphite_dawn_bridge_command(repo string, source string, build string, output string, minimum string) []string {
	external := os.join_path(source, 'third_party/externals')
	mut command := ['clang++', '-std=c++20', '-O2', '-DNDEBUG', '-fno-rtti', '-fPIC', '-dynamiclib',
		'-fvisibility=hidden', '-fvisibility-inlines-hidden', '-mmacosx-version-min=' + minimum,
		'-DSK_GRAPHITE', '-DSK_DAWN', '-DSK_GRAPHITE_USE_LEGACY_RRECT_CLIP_SHADER', '-I' + repo,
		'-I' + source, '-I' + os.join_path(external, 'dawn/include'),
		'-I' + os.join_path(build, 'gen/include'),
		os.join_path(repo, 'native_graphite_dawn_darwin.mm'),
		'-L' + os.join_path(source, 'out/Release'), '-L' + os.join_path(build, 'src/dawn/native'),
		'-Wl,-hidden-lskia', '-Wl,-hidden-lskcms', '-Wl,-hidden-lwebgpu_dawn']
	for framework in ['CoreText', 'Metal', 'CoreGraphics', 'Foundation', 'ImageIO', 'IOSurface',
		'IOKit', 'QuartzCore', 'Cocoa'] {
		command << ['-framework', framework]
	}
	for symbol in graphite_dawn_exports { command << '-Wl,-exported_symbol,_' + symbol }
	command << ['-Wl,-install_name,@rpath/libVoxGraphiteDawn.dylib', '-o', output]
	return command
}

fn graphite_dawn_dependencies(external string) ! {
	dependencies := {
		'dawn':           '42d0e90fe3552a2a8e95ca8e506bc19bbda12729'
		'abseil-cpp':     '2d78d7ce09549caca58fc28b442bbad3a19da432'
		'spirv-headers':  '04fd3caa1e8267e4d95c806cad901181728e1006'
		'webgpu-headers': 'b5ff182caa90e53293f47939716281342c0812ba'
	}
	for name, revision in dependencies {
		target := os.join_path(external, name)
		if !os.exists(os.join_path(target, '.git')) {
			return graphite_missing_dependency(target)
		}
		actual := capture_command(['git', '-C', target, 'rev-parse', 'HEAD'])!.trim_space()
		if actual != revision {
			return error('Unexpected ${name} revision: ${actual}; see docs/MACOS_BUILD.md.')
		}
		result := capture_result(['git', '-C', target, 'diff', '--quiet'])!
		if result.exit_code != 0 {
			return error('Unexpected tracked changes in dependency: ${name}; see docs/MACOS_BUILD.md.')
		}
	}
}

fn build_graphite_dawn(repo string, args []string) ! {
	$if !macos {
		return error('This backend requires macOS')
	}
	output := os.abs_path(required_option(args, '--output')!)
	required_option(args, '--skia-root')!
	archive := graphite_archive(repo)!
	root := os.join_path(repo, 'Build/deps/skia-brave-dawn')
	source := os.join_path(root, 'source')
	graphite_require_file(os.join_path(source, 'DEPS'))!
	// The original Dawn bootstrap predates .vox-revision. Authenticate its
	// unchanged DEPS against the already verified archive without rewriting it.
	expected_deps := capture_command(['tar', '-xOzf', archive,
		'skia-' + graphite_skia_revision + '/DEPS'])!
	if os.read_file(os.join_path(source, 'DEPS'))! != expected_deps {
		return error('Unrecognized Dawn Skia source revision: ${source}; see docs/MACOS_BUILD.md.')
	}
	graphite_validate_patches(source, {
		'src/gpu/graphite/BufferManager.cpp':             'd9adf241a756610b73cb163be55e3dfeeef52eeb7edbe2489ae092c223562205'
		'src/gpu/graphite/dawn/DawnResourceProvider.cpp': '298c27c0afa66d0bd05550c262dab0fd9d053f6f1aacd5d18bc45d6bb5551318'
	})!
	external := os.join_path(source, 'third_party/externals')
	graphite_dawn_dependencies(external)!
	build := os.join_path(root, 'dawn-build')
	for path in [os.join_path(source, 'out/Release/libskia.a'),
		os.join_path(source, 'out/Release/libskcms.a'),
		os.join_path(build, 'src/dawn/native/libwebgpu_dawn.a')] {
		graphite_require_file(path)!
	}
	headers := os.join_path(build, 'gen/include')
	if !os.is_dir(headers) || os.walk_ext(headers, '.h').len == 0 {
		return graphite_missing_dependency(headers)
	}
	make_directory(os.dir(output))!
	run_command(graphite_dawn_bridge_command(repo, source, build, output, graphite_deployment_target(repo)!))!
}
