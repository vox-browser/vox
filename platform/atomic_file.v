module platform

import os

$if windows {
	#include <windows.h>
	fn C.MoveFileExW(&u16, &u16, u32) i32
}

// Replace a file in the same filesystem without exposing a missing or partial
// destination. The Windows CRT rename refuses an existing destination.
pub fn atomic_replace_file(source string, destination string) ! {
	$if windows {
		wide_source := source.replace('/', '\\').to_wide()
		wide_destination := destination.replace('/', '\\').to_wide()
		defer {
			unsafe {
				free(wide_source)
				free(wide_destination)
			}
		}
		// MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH.
		if C.MoveFileExW(wide_source, wide_destination, u32(1 | 8)) == 0 {
			return os.last_error()
		}
	} $else {
		os.rename_dir(source, destination)!
	}
}
