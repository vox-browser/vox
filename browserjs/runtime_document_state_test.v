module browserjs

fn test_document_state_inspection_preserves_pending_replay() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	assert !runtime.has_pending_document_state()
	runtime.mark_document_state_dirty()
	assert runtime.has_pending_document_state()
	assert runtime.has_pending_document_state()
	assert runtime.take_document_state_dirty()
	assert !runtime.has_pending_document_state()
}
