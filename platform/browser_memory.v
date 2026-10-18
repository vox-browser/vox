module platform

$if gcboehm ? {
	fn C.GC_gcollect_and_unmap()
}

// Under -prealloc each spawned thread allocates inside a scoped arena that is
// freed when the thread returns. Browser workers hand fetched resources and
// documents to the main thread, so they keep that arena for the process, as
// they keep the main thread's arena. Without -prealloc this does nothing.
pub fn retain_thread_allocations() {
	$if prealloc {
		_ = unsafe { prealloc_scope_retain_current() }
	}
}

// Return unused heap pages after document work has become idle. Live DOM,
// layout, JavaScript wrappers and retained paint data remain collector roots.
pub fn release_unused_browser_memory() {
	$if gcboehm ? {
		C.GC_gcollect_and_unmap()
	}
}
