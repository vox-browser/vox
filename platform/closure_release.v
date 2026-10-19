module platform

// The V runtime keeps every closure's captured context reachable until the
// closure is destroyed, and the compiler destroys only closures that never
// leave their declaring function. A closure passed to another function, such
// as a traversal callback or a stored hook, otherwise keeps what it captured,
// often a whole document, alive for the rest of the process.
fn C.closure__closure_try_destroy(closure voidptr)

// Release a closure that its owner will not call again, together with its
// captured context. A plain function, or a closure already released, is left
// unchanged. The caller must own the closure: releasing one that another
// object still holds leaves that object with an invalid function.
pub fn release_closure(callback voidptr) {
	if callback == unsafe { nil } {
		return
	}
	C.closure__closure_try_destroy(callback)
}
