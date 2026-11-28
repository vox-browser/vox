module libjs

import os

$if macos {
	#include <mach-o/dyld.h>
	fn C._NSGetExecutablePath(buffer &u8, size &u32) int
}

// os.executable() uses dyld image zero on macOS, which can be an injected
// library. Cache identity must describe the process's actual executable.
fn native_cache_executable() !string {
	$if macos {
		mut size := u32(1024)
		mut bytes := []u8{len: int(size)}
		if C._NSGetExecutablePath(bytes.data, &size) != 0 {
			if size == 0 || size > 1024 * 1024 {
				return error('Invalid native executable path size')
			}
			bytes = []u8{len: int(size)}
			if C._NSGetExecutablePath(bytes.data, &size) != 0 {
				return error('Cannot identify native cache executable')
			}
		}
		return os.real_path(unsafe { cstring_to_vstring(bytes.data) })
	} $else {
		path := os.executable()
		if path == '' { return error('Cannot identify native cache executable') }
		return os.real_path(path)
	}
}
