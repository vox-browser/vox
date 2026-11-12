module buildtools

import os

fn prepare_windows_jsc(a Args) ! {
	dll := real(a.positional(0, ''))
	header := read(join(root_dir(), 'browserjs/include/JavaScriptCore/JavaScript.h'))!
	mut required := []string{}
	for line in header.split_into_lines() {
		if line.starts_with('JS_EXPORT ') && line.contains('(') {
			fields := line.all_before('(').fields()
			if fields.len > 0 && fields.last().starts_with('JS') { required << fields.last() }
		}
	}
	if required.len == 0 { return error('No JavaScriptCore API declarations found') }
	exports := capture([a.get('--objdump', os.getenv_opt('OBJDUMP') or { 'objdump' }), '-p', dll])!
	if !exports.contains('pei-x86-64') {
		return error('JavaScriptCore must be a Windows x86-64 DLL')
	}
	mut available := []string{}
	for line in exports.split_into_lines() {
		text := line.trim_space()
		if text.starts_with('[') && text.fields().len > 0 && text.fields().last().starts_with('JS') {
			available << text.fields().last()
		}
	}
	missing := required.filter(it !in available)
	if missing.len > 0 { return error('JavaScriptCore DLL lacks: ' + missing.join(', ')) }
	output := join(root_dir(), 'Build/deps/windows/native')
	mkdir(output)!
	required.sort()
	definition := join(output, 'JavaScriptCore.def')
	atomic_write(definition, 'LIBRARY ' + os.file_name(dll) + '\nEXPORTS\n' + required.join('\n') + '\n')!
	archive := join(output, 'libJavaScriptCore.dll.a')
	tmp := archive + '.tmp.a'
	checked([a.get('--dlltool', os.getenv_opt('DLLTOOL') or { 'dlltool' }), '-m', 'i386:x86-64',
		'-d', definition, '-l', tmp])!
	os.rename(tmp, archive)!
	println('Imported ${required.len} verified JavaScriptCore exports: ${archive}')
}

fn build_windows(a Args) ! {
	prefix := if os.user_os() == 'windows' { '' } else { 'x86_64-w64-mingw32-' }
	for key, command in {
		'CC':      'gcc'
		'CXX':     'g++'
		'AR':      'ar'
		'OBJDUMP': 'objdump'
		'DLLTOOL': 'dlltool'
	} {
		if os.getenv(key).len == 0 { os.setenv(key, prefix + command, true) }
	}
	if a.has('--deps-root') {
		root := real(a.required('--deps-root')!)
		os.setenv('PKG_CONFIG_LIBDIR', join(root, 'mingw64/lib/pkgconfig'), true)
		os.setenv('PKG_CONFIG_SYSROOT_DIR', root, true)
		os.unsetenv('PKG_CONFIG_PATH')
	}
	os.setenv('V_MACOS_V3_NO_FALLBACK', '1', true)
	prepare_windows_jsc(arguments([real(a.required('--javascriptcore-dll')!)], []string{})!)!
	build_linux_native('windows')!
	selected := compiler()
	modules := prepare_ui(selected)!
	output := absolute(a.required('--output')!)
	mkdir(os.dir(output))!
	scratch := temporary(os.temp_dir(), 'vox-windows-compile-')!
	defer { remove(scratch) or {} }
	os.setenv('VTMP', scratch, true)
	mut flags := ['-b', 'c', '-prod', '-no-prod-options']
	if a.has('--console') { flags << ['-subsystem', 'console'] }
	checked([selected, '-memory-limit', '10G', ...flags, '-enable-globals', '-gc', 'none', '-os',
		'windows', '-arch', 'amd64', '-cc', os.getenv('CC'), '-d', 'ui2_custom_rendering', '-d',
		'sokol_d3d11', '-path', '${root_dir()}|${modules}|@vmodules|@vlib', '-o', output, root_dir()])!
	if !read(output)!.starts_with('MZ') {
		return error('Compiler did not produce a Windows executable')
	}
	println('Built Windows Vox: ${output}')
}

fn development_command(a Args) ! {
	os.unsetenv('VFLAGS')
	mut selected := real(a.get('--compiler', compiler()))
	if !os.is_file(selected) { return error('V compiler does not exist: ${selected}') }
	if os.user_os() == 'linux' { selected = prepare_match(selected)! }
	if os.user_os() == 'macos' { build_harfbuzz()! }
	if os.user_os() in ['linux', 'windows'] { build_linux_native(os.user_os())! }
	if os.user_os() == 'windows' {
		prepare_windows_jsc(arguments([real(a.required('--javascriptcore-dll')!)], []string{})!)!
	}
	mut modules := [prepare_ui(selected)!, prepare_http(selected)!]
	if os.user_os() == 'linux' { modules.prepend(prepare_linux(selected)!) }
	mut flags := ['-b', 'c', '-enable-globals', '-memory-limit', '10G', '-no-parallel', '-cc',
		if os.user_os() == 'windows' { 'gcc' } else { 'clang' }, '-path',
		[root_dir(), ...modules, '@vmodules', '@vlib'].join('|')]
	if os.user_os() == 'linux' {
		flags << ['-d', 'dynamic_boehm', '-d', 'use_openssl', '-exclude', '@vlib/time/zoneinfo.native.v',
			'-cflags', '-D_GNU_SOURCE=1', '-o', join(root_dir(), 'Build/linux/vox')]
	}
	if os.user_os() == 'windows' {
		flags << ['-gc', 'none', '-d', 'ui2_custom_rendering', '-d', 'sokol_d3d11', '-prod',
			'-no-prod-options']
	}
	values := {
		'V_BIN':  selected
		'VFLAGS': shell_join(flags)
	}
	if a.get('--shell', if os.user_os() == 'windows' { 'powershell' } else { 'sh' }) == 'powershell' {
		for key, value in values { println("\$env:${key} = '" + value.replace("'", "''") + "'") }
		println('function global:v { & \$env:V_BIN @args }')
	} else {
		for key, value in values { println('export ${key}=' + quote(value)) }
		println('v() { "$V_BIN" "$@"; }')
	}
}
