module buildtools

import os

// MSYS2's Mesa package disables EGL/GLES. Use matching, pinned upstream
// mesa-dist-win development files and runtime; never reuse ANGLE import libs.
fn prepare_windows_mesa(root string) !string {
	base := join(root, 'mesa')
	mkdir(base)!
	config := load(join(root_dir(), 'tools/windows_mesa.json'))!
	mesa_version := config['version']!.str()
	for kind in ['devel-mingw', 'release-mingw'] {
		expected := config[kind]!.str()
		name := 'mesa3d-${mesa_version}-${kind}.7z'
		archive := join(base, name)
		if !os.is_file(archive) {
			staged := archive + '.download'
			defer { remove(staged) or {} }
			checked(['curl', '--fail', '--location', '--retry', '2', '--output', staged,
				'https://github.com/pal1000/mesa-dist-win/releases/download/${mesa_version}/${name}'])!
			if digest(staged)! != expected { return error('Mesa archive checksum mismatch: ${name}') }
			os.rename(staged, archive)!
		}
		if digest(archive)! != expected { return error('Mesa archive checksum mismatch: ${name}') }
		// Re-extract verified archives so a modified dependency cannot silently
		// become the build's Mesa implementation on a later invocation.
		seven := os.getenv_opt('SEVENZIP') or {
			os.find_abs_path_of_executable('7zz') or { '7z' }
		}
		_ := capture([seven, 'x', '-y', '-o' + join(base, kind), archive])!
	}
	for dll in ['libEGL.dll', 'libGLESv2.dll', 'libgallium_wgl.dll'] {
		if !os.is_file(join(base, 'release-mingw/x64', dll)) {
			return error('Mesa runtime is missing ${dll}')
		}
	}
	pc := join(base, 'lib/pkgconfig')
	mkdir(pc)!
	write_changed(join(pc, 'vox-mesa-egl.pc'), 'prefix=\${pcfiledir}/../..
Name: vox-mesa-egl
Description: Pinned native Mesa EGL and GLES for Vox on Windows
Version: ${mesa_version}
Cflags: -I"\${prefix}/devel-mingw/include"
Libs: -L"\${prefix}/devel-mingw/lib/x64" -lEGL -lGLESv2
')!
	return pc
}

fn windows_mesa_environment(root string) ! {
	pc := prepare_windows_mesa(root)!
	old := os.getenv('PKG_CONFIG_PATH')
	separator := if os.user_os() == 'windows' { ';' } else { ':' }
	os.setenv('PKG_CONFIG_PATH', pc + if old.len > 0 { separator + old } else { '' }, true)
}
