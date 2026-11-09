module main

import crypto.sha256
import crypto.sha512
import json2 as json
import os

fn run_in(directory string, command []string) ! {
	run_command(['sh', '-c', r'cd "$1" && shift && exec "$@"', 'vox-build', directory, ...command])!
}

fn run_to_stderr(command []string) ! {
	run_command(['sh', '-c', r'exec "$@" >&2', 'vox-build', ...command])!
}

fn executable(name string, fallback string) !string {
	if value := os.getenv_opt(name.to_upper()) {
		if value != '' { return value }
	}
	if found := os.find_abs_path_of_executable(name) { return found }
	if fallback != '' && os.is_executable(fallback) { return fallback }
	return error('Missing ${name}; install the native build dependencies')
}

fn browser_backend(repo string) !string {
	mut values := []string{}
	for line in os.read_lines(os.join_path(repo, 'v.mod'))! {
		text := line.trim_space()
		if !text.starts_with('backend:') { continue }
		value := text.all_after('backend:').all_before('//').trim_space().trim_right(',').trim_space()
		if value !in ["'c'", '"c"', "'fastc'", '"fastc"'] {
			return error('v.mod must declare exactly one backend: c or fastc')
		}
		values << value[1..value.len - 1]
	}
	if values.len != 1 { return error('v.mod must declare exactly one backend: c or fastc') }
	return values[0]
}

fn renderer_compiler(_ string, args []string) !string {
	if args.len == 0 { return error('renderer requires a V compiler') }
	legacy := option_value(args, '--skia', '0')! == '1'
	mut compiler := args[0]
	work := make_temp_directory(os.temp_dir(), 'vox-renderer-')!
	defer { os.rmdir_all(work) or {} }
	if !legacy && !os.is_dir(os.join_path(compiler_vlib(compiler, work)!, 'gg/canvas')) {
		fallback := option_value(args, '--fallback', '')!
		if '--explicit' !in args && os.is_file(fallback) && os.is_dir(os.join_path(compiler_vlib(fallback, work)!, 'gg/canvas')) {
			eprintln('GG default: selecting compiler ${fallback}')
			compiler = fallback
		} else {
			return error('The default renderer requires a V compiler with gg.canvas. Set V_BIN to that compiler, or build the legacy renderer with VOX_USE_SKIA=1.')
		}
	}
	receipt := option_value(args, '--receipt', '')!
	if receipt != '' {
		data := {
			'default':           json.Any(if legacy { 'skia' } else { 'gg' })
			'compiler':          json.Any(compiler)
			'gg_adapters':       json.Any(!legacy)
			'skia_free':         json.Any(false)
			'skia_required_for': json.Any([json.Any('text preparation and fallback'), 'canvas',
				'shadows', 'bitmap export', 'recording and picture playback'])
		}
		atomic_write_json_text(receipt, json.encode(data))!
	}
	return compiler
}

struct NativeGroup {
	package      string
	names        []string
	dependencies []string
}

fn build_native(repo string, args []string) ! {
	target_os := option_value(args, '--os', 'linux')!
	if target_os !in ['linux', 'windows'] {
		return error('Unsupported native target: ${target_os}')
	}
	output := os.join_path(repo, if target_os == 'windows' {
		'Build/deps/windows/native'
	} else {
		'Build/linux/native'
	})
	make_directory(output)!
	compiler := shell_split(env_default('CXX', 'c++'))!
	version := capture_command([...compiler, '--version'])!
	mut groups := [
		NativeGroup{'platform', ['unicode_case_mapping'], ['icu-uc', 'icu-i18n']},
		NativeGroup{'gfxfont', ['woff2'], if target_os == 'windows' {
			['libwoff2dec']
		} else {
			[]string{}
		}},
		NativeGroup{'skia', ['canvas_raster', 'shadow_raster'], ['skia']},
	]
	if target_os == 'windows' {
		groups << NativeGroup{'webgl', ['native_windows'], ['angleproject']}
	}
	for group in groups {
		flags := if group.dependencies.len > 0 {
			shell_split(capture_command(['pkg-config', '--cflags', ...group.dependencies])!)!
		} else {
			[]string{}
		}
		mut inputs := version + json.encode(flags) + os.read_file(os.join_path(repo, 'tools/voxbuild/native.v'))!
		mut sources := []string{}
		for name in group.names {
			sources << os.join_path(repo, group.package, name + if group.package == 'webgl' {
				'.c'
			} else {
				'.cpp'
			})
		}
		mut headers := os.ls(os.join_path(repo, group.package))!.filter(it.ends_with('.h'))
		headers.sort()
		for source in sources { inputs += hash_file(source)! }
		for header in headers { inputs += hash_file(os.join_path(repo, group.package, header))! }
		digest := sha256.hexhash(inputs)
		archive := os.join_path(output, group.package + '.a')
		stamp := os.join_path(output, group.package + '.sha256')
		if os.is_file(archive) && os.is_file(stamp) && os.read_file(stamp)! == digest { continue }
		mut objects := []string{}
		for source in sources {
			target := os.join_path(output, os.file_name(source).all_before_last('.') + '.o')
			selected := if source.ends_with('.c') {
				shell_split(env_default('CC', 'cc'))!
			} else {
				compiler
			}
			standard := if source.ends_with('.c') { '-std=gnu11' } else { '-std=c++20' }
			run_command([...selected, standard, '-O2', '-fPIC', ...flags, '-c', source, '-o', target])!
			objects << target
		}
		temporary := archive + '.tmp.a'
		if os.exists(temporary) { os.rm(temporary)! }
		run_command([...shell_split(env_default('AR', 'ar'))!, 'rcs', temporary, ...objects])!
		os.rename(temporary, archive)!
		os.write_file(stamp, digest)!
		println('Built ${target_os} ${group.package} bridge')
	}
}

fn build_avif(repo string, args []string) !string {
	output := os.abs_path(required_option(args, '--output')!)
	make_directory(os.dir(output))!
	mut flags := []string{}
	$if macos {
		machine := capture_command(['uname', '-m'])!.trim_space()
		triplet := if machine == 'arm64' { 'arm64-osx-dynamic' } else { 'x64-osx-dynamic' }
		sdk := option_value(args, '--sdk-root', os.join_path(repo, '../3rd/ladybird/Build/release/vcpkg_installed', triplet))!
		flags = ['-I${sdk}/include', '-L${sdk}/lib', '-lavif', '-Wl,-rpath,${sdk}/lib', '-dynamiclib',
			'-Wl,-install_name,@rpath/libVoxAVIF.dylib']
	} $else $if linux {
		flags = shell_split(capture_command(['pkg-config', '--cflags', '--libs', 'libavif'])!)!
		flags << ['-shared', '-Wl,-soname,libVoxAVIF.so']
	} $else {
		return error('The native AVIF helper requires macOS or Linux')
	}
	optimize := if '--sanitize' in args {
		['-O1', '-g', '-fsanitize=address,undefined', '-fno-omit-frame-pointer']
	} else {
		['-O2']
	}
	work := make_temp_directory(os.dir(output), '.avif-')!
	defer { os.rmdir_all(work) or {} }
	staged := os.join_path(work, os.file_name(output))
	run_command([env_default('CC', 'clang'), '-std=c11', '-fPIC', '-fvisibility=hidden', ...optimize,
		os.join_path(repo, 'native_avif.c'), ...flags, '-o', staged])!
	os.rename(staged, output)!
	return output
}

fn verified_download(url string, archive string, expected string, algorithm string) ! {
	make_directory(os.dir(archive))!
	if !os.is_file(archive) {
		work := make_temp_directory(os.dir(archive), '.download-')!
		defer { os.rmdir_all(work) or {} }
		candidate := os.join_path(work, 'archive')
		run_command(['curl', '--fail', '--location', '--retry', '3', '--output', candidate, url])!
		check_archive_digest(candidate, expected, algorithm)!
		os.rename(candidate, archive)!
	}
	check_archive_digest(archive, expected, algorithm)!
}

fn check_archive_digest(path string, expected string, algorithm string) ! {
	mut actual := ''
	if algorithm == 'sha512' {
		mut digest := sha512.new()
		actual = file_digest(path, mut digest)!
	} else {
		actual = hash_file(path)!
	}
	if actual != expected { return error('Dependency archive checksum mismatch: ${path}') }
}

fn extract_pinned_archive(archive string, destination string, prefix string) ! {
	// Callers authenticate the complete pinned archive before extraction. Keep
	// even authenticated paths beneath the single expected archive root.
	names := capture_command(['tar', '-tzf', archive])!
	for name in names.split_into_lines() {
		if name.starts_with('/') || '..' in name.split('/') || (name != prefix && !name.starts_with(prefix + '/')) {
			return error('Unexpected dependency archive member: ${name}')
		}
	}
	make_directory(destination)!
	run_command(['tar', '-xzf', archive, '-C', destination])!
}

fn build_linux_skia(repo string) ! {
	$if !linux {
		return error('This dependency build must run on Linux')
	}
	for tool in ['gn', 'ninja', 'clang', 'clang++', 'pkg-config'] { executable(tool, '')! }
	revision := 'ee20d565acb08dece4a32e3f209cdd41119015ca'
	digest := 'afa54cb14b76e9b2f40498c5daf93cec951d12d7f3487deba6f8f94a66d046a5625561e1ccd65f2e9ef5e2fc1a3158c3da4fb9658bcf268248a34c49dea90d3a'
	root := os.join_path(repo, 'Build/deps')
	archive := os.join_path(root, 'skia.tar.gz')
	verified_download('https://codeload.github.com/google/skia/tar.gz/${revision}', archive, digest, 'sha512')!
	source := os.join_path(root, 'skia')
	stamp := os.join_path(source, '.vox-revision')
	if !os.exists(source) {
		temporary := make_temp_directory(root, '.skia-')!
		defer { os.rmdir_all(temporary) or {} }
		extract_pinned_archive(archive, temporary, 'skia-${revision}')!
		os.rename_dir(os.join_path(temporary, 'skia-${revision}'), source)!
		os.write_file(stamp, revision + '\n')!
	} else if !os.is_file(stamp) || os.read_file(stamp)!.trim_space() != revision {
		return error('Unrecognized Skia source tree: ${source}')
	}
	build_file := os.join_path(source, 'BUILD.gn')
	text := os.read_file(build_file)!
	component := text.index('skia_component("skia") {') or { return error('Missing Skia component') }
	original := '    ":jpeg_encode",\n    ":pdf",'
	replacement := '    ":jpeg_encode",\n    ":pathops",\n    ":pdf",'
	tail := text[component..]
	if tail.contains(original) {
		if tail.count(original) != 1 { return error('Unrecognized Skia pathops dependency list') }
		os.write_file(build_file, text[..component] + tail.replace_once(original, replacement))!
	} else if !tail.contains(replacement) {
		return error('Unrecognized Skia pathops dependency list')
	}
	gn_args := ['is_official_build=true is_debug=false cc="clang" cxx="clang++"',
		'skia_enable_ganesh=false skia_enable_graphite=false skia_enable_pdf=false',
		'skia_enable_tools=false skia_use_icu=false skia_use_harfbuzz=false',
		'skia_use_freetype=true skia_use_fontconfig=true skia_use_wuffs=false',
		'skia_use_piex=false skia_use_dng_sdk=false skia_use_expat=false',
		'skia_use_libavif=false skia_use_lua=false extra_cflags=["-fPIC"]'].join(' ')
	run_in(source, ['gn', 'gen', 'out/Release', '--args=${gn_args}'])!
	run_in(source, ['ninja', '-C', 'out/Release', '-j', env_default('JOBS', '3'), 'skia'])!
	write_if_changed(os.join_path(root, 'lib/pkgconfig/skia.pc'),
		'prefix=${source}\nName: skia\nDescription: Vox CPU Skia\nVersion: 144\n' +
			r'Libs: -L${prefix}/out/Release -lskia -lskcms -lstdc++ -ldl -lpthread -lm' + '\n' +
			'Requires: freetype2 fontconfig libpng libjpeg libwebp libwebpdemux zlib\n' +
			r'Cflags: -I${prefix} -DSK_HIDE_PATH_EDIT_METHODS -DSK_R32_SHIFT=16' + '\n')!
	println('Built Skia ${revision}; run sh build-prod-browser.sh')
}

fn localize_bundle(repo string, executable_path string, build_directory string) ! {
	commands := capture_command(['otool', '-l', executable_path])!
	mut paths := []string{}
	mut is_rpath := false
	for raw in commands.split_into_lines() {
		line := raw.trim_space()
		if line.starts_with('cmd ') { is_rpath = line == 'cmd LC_RPATH' }
		if is_rpath && line.starts_with('path ') && line.contains(' (offset ') {
			paths << line[5..].all_before(' (offset ')
		}
	}
	external := [os.real_path(build_directory), os.real_path(os.join_path(repo, 'Build/v'))]
	mut removed := []string{}
	for path in paths {
		if os.real_path(path) !in external || path in removed { continue }
		if '@executable_path' !in paths {
			return error('Cannot remove the shared runtime path without a bundle-local search path')
		}
		run_command(['install_name_tool', '-delete_rpath', path, executable_path])!
		removed << path
		println('Removed shared runtime search path: ${path}')
	}
}
