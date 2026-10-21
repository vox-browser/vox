module platform

#include "browser_memory_unmap_test.h"

$if gcboehm ? {
	fn C.vox_idle_unmap_prepare()
	fn C.vox_idle_unmap_released() int
}

fn test_idle_cleanup_returns_newly_freed_pages_to_the_os() {
	$if gcboehm ? {
		$if macos || linux {
			C.vox_idle_unmap_prepare()
			release_unused_browser_memory()
			assert C.vox_idle_unmap_released() == 1
		}
	}
}
