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
	if a.has('--sdk-root') && os.user_os() == 'macos' {
		sdk := real(a.required('--sdk-root')!)
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

const hb_version = '15.1.0'
const hb_sha = '5c057929413b8664592fea67edea5c2c47b4ffb0bf5f4accb5164bc6acc69d94'

fn hb_options() []string {
	mut result := ['-DBUILD_SHARED_LIBS=OFF', '-DCMAKE_BUILD_TYPE=Release',
		'-DCMAKE_POSITION_INDEPENDENT_CODE=ON', '-DHB_HAVE_CORETEXT=ON']
	for name in ['GRAPHITE2', 'FREETYPE', 'GLIB', 'ICU', 'CAIRO', 'GOBJECT', 'INTROSPECTION'] {
		result << '-DHB_HAVE_${name}=OFF'
	}
	for name in ['UTILS', 'SUBSET', 'RASTER', 'VECTOR', 'GPU', 'GPU_DEMO'] {
		result << '-DHB_BUILD_${name}=OFF'
	}
	return result
}

fn check_harfbuzz(executable string) ! {
	libraries := capture(['otool', '-L', executable])!
	symbols := capture(['nm', '-u', executable])!
	if libraries.to_lower().contains('graphite2') || symbols.fields().any(it.starts_with('_gr_') || it.starts_with('gr_')) {
		return error('Browser still depends on Graphite2')
	}
}

fn build_harfbuzz() !string {
	if os.user_os() != 'macos' { return error('This isolated HarfBuzz build is for macOS') }
	root := join(root_dir(), 'Build/deps/harfbuzz-${hb_version}')
	mkdir(root)!
	mut held := acquire(join(root, 'build.lock'), true)!
	defer { held.release() }
	cmake := os.find_abs_path_of_executable('cmake')!
	clang := os.find_abs_path_of_executable('clang++')!
	url := 'https://codeload.github.com/harfbuzz/harfbuzz/tar.gz/refs/tags/${hb_version}'
	identity := map[string]json.Any{
		'version':           hb_version
		'url':               url
		'sha256':            hb_sha
		'options':           any_strings(hb_options())
		'builder':           digest(@FILE)!
		'architecture':      capture(['uname', '-m'])!.trim_space()
		'deployment_target': os.getenv_opt('MACOSX_DEPLOYMENT_TARGET') or { '15.0' }
		'compiler':          capture([clang, '--version'])!
		'cmake':             capture([cmake, '--version'])!
	}
	record := maybe_load(join(root, 'build.json'))
	outputs := string_map((record['outputs'] or { json.Null{} }))
	if (record['inputs'] or { json.Null{} }).as_map() == identity && 'lib/libharfbuzz.a' in outputs && 'include/harfbuzz/hb.h' in outputs {
		mut valid := true
		for name, sha in outputs {
			if !os.is_file(join(root, name)) || (digest(join(root, name)) or { '' }) != sha {
				valid = false
				break
			}
		}
		if valid { return root }
	}
	archive := join(root, 'source.tar.gz')
	if !os.is_file(archive) {
		staged := archive + '.download'
		checked(['curl', '--fail', '--location', '--output', staged, url])!
		if digest(staged)! != hb_sha { return error('HarfBuzz archive checksum mismatch') }
		os.rename(staged, archive)!
	}
	if digest(archive)! != hb_sha { return error('HarfBuzz archive checksum mismatch') }
	work := temporary(root, 'compile-')!
	defer { remove(work) or {} }
	for path in capture(['tar', '-tzf', archive])!.split_into_lines() {
		if path.starts_with('/') || '..' in path.split('/') || path.split('/')[0] != 'harfbuzz-${hb_version}' {
			return error('Invalid HarfBuzz archive path')
		}
	}
	for line in capture(['tar', '-tvzf', archive])!.split_into_lines() {
		if line.len > 0 && line[0] !in [`-`, `d`] && !(line[0] == `l` && line.contains('harfbuzz-${hb_version}/CLAUDE.md')) {
			return error('Unsupported HarfBuzz archive entry')
		}
	}
	checked(['tar', '-xzf', archive, '-C', work, '--exclude=harfbuzz-${hb_version}/CLAUDE.md'])!
	output := join(work, 'build')
	command := [cmake, '-S', join(work, 'harfbuzz-${hb_version}'), '-B', output,
		'-DCMAKE_CXX_COMPILER=${clang}',
		'-DCMAKE_OSX_DEPLOYMENT_TARGET=' + (identity['deployment_target'] or { json.Null{} }).str(),
		'-DCMAKE_INSTALL_PREFIX=${root}', ...hb_options()]
	// Build chatter goes to stderr: stdout is the resulting dependency prefix.
	for cmd in [command, [cmake, '--build', output, '--parallel', '2'], [cmake, '--install', output]] {
		checked(['sh', '-c', 'exec "$@" >&2', 'sh', ...cmd])!
	}
	os.cp(join(work, 'harfbuzz-${hb_version}/COPYING'), join(root, 'LICENSE'))!
	mut output_paths := [join(root, 'lib/libharfbuzz.a'), join(root, 'LICENSE')]
	output_paths << (listing(join(root, 'include/harfbuzz'))!).filter(it.ends_with('.h'))
	mut hashes := map[string]string{}
	for path in output_paths { hashes[relative(path, root)] = digest(path)! }
	write_json(join(root, 'build.json'), json.Any(map[string]json.Any{
		'inputs':            json.Any(identity)
		'configure_command': any_strings(command)
		'outputs':           record_strings(hashes)
	}))!
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
