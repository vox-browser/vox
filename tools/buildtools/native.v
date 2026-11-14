module buildtools

import os
import json2 as json

fn browser_backend(root string) !string {
	mut values := []string{}
	for line in read(join(root, 'v.mod'))!.split_into_lines() {
		text := line.trim_space()
		if !text.starts_with('backend:') { continue }
		value := text.all_after('backend:').all_before('//').trim_space().trim_right(',').trim_space()
		if value !in ["'c'", '"c"', "'fastc'", '"fastc"'] {
			return error('v.mod must declare exactly one backend: c or fastc')
		}
		values << value.trim('\'"')
	}
	if values.len != 1 { return error('v.mod must declare exactly one backend: c or fastc') }
	return values[0]
}

fn pre_commit(root string) !int {
	output := capture(['git', '-C', root, 'diff', '--cached', '--raw', '-z', '--no-renames',
		'--no-abbrev', '--diff-filter=ACM'])!
	fields := output.split('\x00')
	mut problems := []string{}
	for i := 0; i + 1 < fields.len; i += 2 {
		parts := fields[i].fields()
		path := fields[i + 1]
		if parts.len < 4 { return error('Malformed staged Git diff') }
		if parts[1] == '160000' { continue }
		size := capture(['git', '-C', root, 'cat-file', '-s', parts[3]])!.trim_space().i64()
		lower := path.to_lower()
		if path == 'Build' || path.starts_with('Build/') {
			problems << '${path}: Build/ is local scratch'
		} else if (path.starts_with('docs/performance/') || path.starts_with('docs/benchmark-results/')) && [
			'.json',
			'.jsonl',
			'.ndjson',
		].any(lower.ends_with(it)) {
			problems << '${path}: measurement dumps stay local; commit a Markdown summary instead'
		} else if ['.gz', '.tgz', '.zip', '.tar', '.xz', '.zst', '.7z', '.bz2', '.tbz2', '.txz',
			'.rar'].any(lower.ends_with(it)) && !['adblock/', 'tools/adblock/fixtures/',
			'Tests/Browser/Brave/candidates/'].any(path.starts_with(it)) {
			problems << '${path}: archives stay local; commit the report or manifest instead'
		} else if size > 32 * 1048576 {
			problems << '${path}: ${f64(size) / 1048576:.1f} MiB exceeds the 32 MiB limit'
		}
	}
	if problems.len == 0 { return 0 }
	eprintln('Commit rejected by tools/pre_commit_check.vsh:\n  ' + problems.join('\n  '))
	return 1
}

fn rpaths(text string) []string {
	mut result := []string{}
	mut pending := false
	for line in text.split_into_lines() {
		if trimmed_eq(line, 'cmd LC_RPATH') {
			pending = true
			continue
		}
		if pending && line.trim_space().starts_with('path ') {
			result << line.trim_space().trim_string_left('path ').all_before(' (offset ')
			pending = false
		}
	}
	return result
}

fn localize(executable string, build_directory string) ! {
	paths := rpaths(capture(['otool', '-l', executable])!)
	external := [real(build_directory), real(join(root_dir(), 'Build/v'))]
	mut removed := []string{}
	for path in paths {
		if real(path) !in external || path in removed { continue }
		if '@executable_path' !in paths {
			return error('Cannot remove shared runtime path without bundle-local search path')
		}
		checked(['install_name_tool', '-delete_rpath', path, executable])!
		removed << path
		println('Removed shared runtime search path: ${path}')
	}
}

fn build_avif(a Args) ! {
	output := absolute(a.required('--output')!)
	mkdir(os.dir(output))!
	mut flags := []string{}
	if os.user_os() == 'macos' {
		sdk := if a.has('--sdk-root') {
			real(a.required('--sdk-root')!)
		} else {
			macos_dependency_prefix('libavif')!
		}
		flags = ['-I' + join(sdk, 'include'), '-L' + join(sdk, 'lib'), '-lavif',
			'-Wl,-rpath,' + join(sdk, 'lib')]
	} else {
		flags = shell_split(capture(['pkg-config', '--cflags', '--libs', 'libavif'])!)!
	}
	if os.user_os() == 'macos' {
		flags << ['-dynamiclib', '-Wl,-install_name,@rpath/libVoxAVIF.dylib']
	} else if os.user_os() == 'linux' {
		flags << ['-shared', '-Wl,-soname,libVoxAVIF.so']
	} else {
		return error('AVIF helper requires macOS or Linux')
	}
	optimize := if a.has('--sanitize') {
		['-O1', '-g', '-fsanitize=address,undefined', '-fno-omit-frame-pointer']
	} else {
		['-O2']
	}
	tmp := temporary(os.dir(output), '.avif-')!
	defer { remove(tmp) or {} }
	staged := join(tmp, os.file_name(output))
	checked([os.getenv_opt('CC') or { 'clang' }, '-std=c11', '-fPIC', '-fvisibility=hidden',
		...optimize, join(root_dir(), 'native_avif.c'), ...flags, '-o', staged])!
	os.rename(staged, output)!
	println(output)
}

const hb_module_revision = '46cfa89f34c92e8cb5fc6c89ca2743e37c5be18b'
const hb_requirement = 'https://github.com/vlang/harfbuzz@v15.1.0'

fn hb_binary_sha(architecture string) !string {
	return match architecture {
		'arm64' { 'de4706c1224b6d21dbda11e6fed354296b80a624b7e9490d04f4ea8af90e2f26' }
		'amd64' { '047b9df39213dde82daff87262bb7c58a2846b8e2716a745f1f7f86ce68e40df' }
		else { return error('No precompiled macOS HarfBuzz for ${architecture}') }
	}
}

fn hb_artifact_matches(root string, expected_sha string) bool {
	library := join(root, '.vpm-binaries/libharfbuzz.a')
	return !os.is_link(join(root, '.vpm-binaries')) && !os.is_link(library)
		&& os.is_file(join(root, 'include/harfbuzz/hb.h'))
		&& os.is_file(join(root, 'LICENSE.harfbuzz'))
		&& (digest(library) or { '' }) == expected_sha
}

fn check_harfbuzz(executable string) ! {
	libraries := capture(['otool', '-L', executable])!
	symbols := capture(['nm', '-u', executable])!
	if libraries.to_lower().contains('graphite2') || symbols.fields().any(it.starts_with('_gr_') || it.starts_with('gr_')) {
		return error('Browser still depends on Graphite2')
	}
}

// Retain the setup command's name; first builds now fetch a verified VPM
// package rather than compiling the HarfBuzz C++ amalgamation locally.
fn build_harfbuzz() !string {
	if os.user_os() != 'macos' { return error('This HarfBuzz package setup is for macOS') }
	architecture := $if arm64 { 'arm64' } $else $if amd64 { 'amd64' } $else { 'unknown' }
	sha := hb_binary_sha(architecture)!
	root := join(os.vmodules_dir(), 'harfbuzz')
	if hb_artifact_matches(root, sha)
		&& (capture(['git', '-C', root, 'rev-parse', 'HEAD']) or { '' }).trim_space() == hb_module_revision {
		return root
	}
	// Keep stdout usable by dev_build_env/build-prod-browser.sh.
	checked(['sh', '-c', 'exec "$@" >&2', 'sh', compiler(), 'install', hb_requirement])!
	if !hb_artifact_matches(root, sha) {
		return error('HarfBuzz binary package is missing or corrupt. Update V to a VPM version with vpm-binaries.json support, then run v install ' + hb_requirement)
	}
	if capture(['git', '-C', root, 'rev-parse', 'HEAD'])!.trim_space() != hb_module_revision {
		return error('HarfBuzz package is not at the pinned release commit')
	}
	return root
}

fn build_linux_native(target_os string) ! {
	output := build_cache(if target_os == 'windows' {
		'deps/windows/native'
	} else {
		'linux/native'
	})
	mkdir(output)!
	if target_os != 'windows' { return }
	cxx := shell_split(os.getenv_opt('CXX') or { 'c++' })!
	version := capture([...cxx, '--version'])!
	flags := shell_split(capture(['pkg-config', '--cflags', 'vox-mesa-egl', 'icu-uc'])!)!
	source := join(root_dir(), 'webgl/native_windows.c')
	mut bytes := version + json.encode(flags) + read(@FILE)! + read(source)!
	for path in (listing(join(root_dir(), 'webgl'))!).filter(it.ends_with('.h')) {
		bytes += read(path)!
	}
	archive := join(output, 'webgl.a')
	stamp := join(output, 'webgl.sha256')
	sha := hash(bytes)
	if os.is_file(archive) && os.is_file(stamp) && read(stamp)! == sha { return }
	object_file := join(output, 'native_windows.o')
	cc := shell_split(os.getenv_opt('CC') or { 'cc' })!
	checked([...cc, '-std=gnu11', '-O2', '-fPIC', ...flags, '-c', source, '-o', object_file])!
	tmp := join(output, 'webgl.tmp.a')
	remove(tmp)!
	ar := shell_split(os.getenv_opt('AR') or { 'ar' })!
	checked([...ar, 'rcs', tmp, object_file])!
	os.rename(tmp, archive)!
	atomic_write(stamp, sha)!
	eprintln('Built ${target_os} webgl bridge')
}
