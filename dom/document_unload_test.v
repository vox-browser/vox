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

fn test_document_unload_records_timing_for_a_same_origin_replacement() {
	mut old_document := Document.create(URL{ value: 'https://example.test/old' })
	old_document.set_origin(old_document.url.origin())
	mut new_document := Document.create(URL{ value: 'https://example.test/new' })
	new_document.set_origin(new_document.url.origin())

	old_document.unload_with_replacement(new_document)

	timing := new_document.document_previous_document_unload_timing()
	assert timing.unload_event_start_time > 0
	assert timing.unload_event_end_time >= timing.unload_event_start_time
}

fn test_document_unload_hides_timing_after_cross_origin_redirects() {
	mut old_document := Document.create(URL{ value: 'https://example.test/old' })
	old_document.set_origin(old_document.url.origin())
	mut new_document := Document.create(URL{ value: 'https://example.test/new' })
	new_document.set_origin(new_document.url.origin())
	new_document.set_was_created_via_cross_origin_redirects(true)

	old_document.unload_with_replacement(new_document)

	assert new_document.document_previous_document_unload_timing() == DocumentUnloadTimingInfo{}
}
