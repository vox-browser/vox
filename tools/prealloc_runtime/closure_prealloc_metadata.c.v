module closure

// The runtime's live-closure directory and page/lifetime records outlive any
// caller arena. Its existing mutex serializes this detached allocation arena,
// including callers on different threads. Captured contexts remain with the
// caller: the compiler constructs them before taking the runtime mutex.
__global (
	closure_metadata_tail voidptr
	closure_metadata_previous voidptr
)

struct ClosureMetadataBlockPrefix {
mut:
	current voidptr
	stop voidptr
	start voidptr
	previous voidptr
}

fn closure_metadata_enter() {
	$if prealloc {
		unsafe {
			if closure_metadata_tail == nil {
				scope := prealloc_scope_begin()
				closure_metadata_tail = voidptr(g_memory_block)
				prealloc_scope_leave(scope)
				(&ClosureMetadataBlockPrefix(closure_metadata_tail)).previous = nil
			}
			closure_metadata_previous = voidptr(g_memory_block)
			g_memory_block = closure_metadata_tail
		}
	}
}

fn closure_metadata_leave() {
	$if prealloc {
		unsafe {
			closure_metadata_tail = voidptr(g_memory_block)
			g_memory_block = closure_metadata_previous
			closure_metadata_previous = nil
		}
	}
}
