module platform

fn test_closure_metadata_preserves_the_selected_document_allocator() {
	$if !prealloc { return }
	mut owner := new_retained_arena('closure caller document')
	mut entry := owner.enter()
	defer { entry.finish(); owner.release() }
	before := current_block()
	value := u64(C.pthread_self())
	callback := fn [value] () u64 { return value + 1 }
	after_create := current_block()
	// Restore for cleanup even when testing a broken runtime. Preserve both
	// observations so the repair cannot turn a failed check into a pass.
	set_current_block(before)
	result := callback()
	release_closure(voidptr(callback))
	after_release := current_block()
	set_current_block(before)
	// -prod omits assert statements; these checks must execute in that mode.
	if after_create != before || after_release != before || result != value + 1 {
		panic('closure metadata changed the caller allocation arena')
	}
	println('Closure creation and release preserve the document allocator')
}
