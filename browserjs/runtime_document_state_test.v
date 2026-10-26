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

@[heap]
struct DocumentStateWakeups {
mut:
	count int
}

fn test_document_state_wakeup_coalesces_until_replayed_and_stops_on_close() {
	mut runtime := Runtime.create()
	mut wakeups := &DocumentStateWakeups{}
	runtime.set_document_state_wakeup(fn [mut wakeups] () { wakeups.count++ })
	assert wakeups.count == 0
	runtime.mark_document_state_dirty()
	runtime.mark_document_state_dirty()
	assert wakeups.count == 1
	assert runtime.has_pending_document_state()
	assert runtime.take_document_state_dirty()
	runtime.mark_document_state_dirty()
	assert wakeups.count == 2
	runtime.close()
	assert !runtime.has_pending_document_state()
	runtime.mark_document_state_dirty()
	assert wakeups.count == 2
	assert !runtime.has_pending_document_state()
}

fn test_document_state_wakeup_installed_after_pending_replay_and_replaced() {
	mut runtime := Runtime.create()
	defer { runtime.close() }
	mut first := &DocumentStateWakeups{}
	mut second := &DocumentStateWakeups{}
	runtime.mark_document_state_dirty()
	runtime.set_document_state_wakeup(fn [mut first] () { first.count++ })
	assert first.count == 1
	runtime.set_document_state_wakeup(fn [mut second] () { second.count++ })
	assert first.count == 1
	assert second.count == 1
	assert runtime.take_document_state_dirty()
	runtime.mark_document_state_dirty()
	assert first.count == 1
	assert second.count == 2
	runtime.set_document_state_wakeup(none)
	assert runtime.take_document_state_dirty()
	runtime.mark_document_state_dirty()
	assert second.count == 2
}
