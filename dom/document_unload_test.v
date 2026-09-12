@[has_globals]
module dom

__global document_unload_cleanup_count int

fn count_document_unload_cleanup(_ voidptr, _ &Document) {
	document_unload_cleanup_count++
}

fn test_document_unload_runs_cleanup_before_destroying_the_document() {
	mut document := Document.create(url_about_blank())
	document.set_lifecycle_hook(DocumentLifecycleHook{
		run_unloading_cleanup_steps: count_document_unload_cleanup
	})
	document_unload_cleanup_count = 0

	document.unload()

	// Unload performs the cleanup at step 18. Destroy performs its own cleanup
	// as well, and both algorithms must keep doing so independently.
	assert document_unload_cleanup_count == 2
	assert document.has_been_destroyed()
}
