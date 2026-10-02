module dom

fn test_style_sheet_request_delay_tracks_source_reason_and_idempotent_finish() {
	mut document := Document.create(URL{})
	mut generic := DocumentLoadEventDelayer.new(mut document)
	mut sheet := DocumentLoadEventDelayer.new_with_reason(mut document, .style_sheet_request)
	assert document.anything_is_delaying_the_load_event()
	assert document.has_pending_style_sheet_requests()
	sheet.finish()
	sheet.finish()
	assert !document.has_pending_style_sheet_requests()
	assert document.anything_is_delaying_the_load_event()
	generic.finish()
	assert !document.anything_is_delaying_the_load_event()
}

fn test_moving_a_delayer_releases_previous_document_and_transfers_source_reason() {
	mut old := Document.create(URL{})
	mut next := Document.create(URL{})
	mut target := DocumentLoadEventDelayer.new_with_reason(mut old, .style_sheet_request)
	mut source := DocumentLoadEventDelayer.new_with_reason(mut next, .style_sheet_request)
	target.move_from(mut source)
	assert !old.has_pending_style_sheet_requests()
	assert !old.anything_is_delaying_the_load_event()
	assert next.has_pending_style_sheet_requests()
	source.finish()
	assert next.has_pending_style_sheet_requests()
	target.finish()
	assert !next.has_pending_style_sheet_requests()
	assert !next.anything_is_delaying_the_load_event()
}

fn test_css_imports_remain_pending_without_a_direct_style_sheet_request() {
	mut document := Document.create(URL{})
	rule := &CSSImportRule{}
	document.add_pending_css_import_rule(rule)
	assert document.has_pending_style_sheet_requests()
	document.remove_pending_css_import_rule(rule)
	assert !document.has_pending_style_sheet_requests()
}
