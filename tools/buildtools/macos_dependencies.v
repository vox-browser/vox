module buildtools

import os

fn macos_dependency_present(prefix string, formula string) bool {
	match formula {
		'libavif' {
			return os.is_file(join(prefix, 'include/avif/avif.h'))
				&& os.is_file(join(prefix, 'lib/libavif.dylib'))
		}
		'ffmpeg' {
			for library, header in {
				'avformat': 'avformat.h'
				'avcodec':  'avcodec.h'
				'avutil':   'avutil.h'
				'swscale':  'swscale.h'
			} {
				if !os.is_file(join(prefix, 'include/lib${library}/${header}'))
					|| !os.is_file(join(prefix, 'lib/lib${library}.dylib')) { return false }
			}
			return true
		}
		else { return false }
	}
}

fn macos_dependency_prefix(formula string) !string {
	if formula !in ['libavif', 'ffmpeg'] { return error('Unsupported macOS dependency: ${formula}') }
	// Query Homebrew for custom installations; standard prefixes also work when
	// brew is absent from PATH. Prefer the host architecture when both exist.
	mut candidates := []string{}
	if brew := os.find_abs_path_of_executable('brew') {
		if prefix := capture([brew, '--prefix', formula]) {
			candidates << prefix.trim_space()
		}
	}
	$if arm64 {
		candidates << ['/opt/homebrew/opt/${formula}', '/usr/local/opt/${formula}']
	} $else {
		candidates << ['/usr/local/opt/${formula}', '/opt/homebrew/opt/${formula}']
	}
	for prefix in candidates {
		if macos_dependency_present(prefix, formula) { return real(prefix) }
	}
	return error('Missing ${formula} headers or libraries (brew install ${formula})')
}
