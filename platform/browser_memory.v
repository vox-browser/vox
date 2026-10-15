module platform

$if gcboehm ? {
	fn C.GC_gcollect_and_unmap()
}

// Return unused heap pages after document work has become idle. Live DOM,
// layout, JavaScript wrappers and retained paint data remain collector roots.
pub fn release_unused_browser_memory() {
	$if gcboehm ? {
		C.GC_gcollect_and_unmap()
	}
}
