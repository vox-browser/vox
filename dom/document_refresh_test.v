module dom

struct DeclarativeRefreshTestState {
mut:
	calls int
	url   string
}

fn record_declarative_refresh(target voidptr, _ &Document, url URL) {
	mut state := unsafe { &DeclarativeRefreshTestState(target) }
	state.calls++
	state.url = url.serialize()
}

fn refresh_test_document(url string, state &DeclarativeRefreshTestState) &Document {
	mut document := Document.create(URL{ value: url })
	document.set_cached_navigable(&Navigable{
		active_document_: document
		is_top_level_traversable_: true
	})
	document.set_html_navigation_hook(DocumentHTMLNavigationHook{
		target: voidptr(state)
		declarative_refresh_navigate: record_declarative_refresh
	})
	return document
}

fn test_shared_declarative_refresh_translates_parser_timer_and_navigation() {
	mut state := &DeclarativeRefreshTestState{}
	mut document := refresh_test_document('https://example.test/a/index.html', state)
	document.shared_declarative_refresh_steps('  1.5 ; URL = \'../next?x=1\' ignored')

	assert document.will_declaratively_refresh
	assert document.last_declarative_refresh_input() or { '' } == '  1.5 ; URL = \'../next?x=1\' ignored'
	assert document.active_refresh_timer != unsafe { nil }
	assert document.active_refresh_timer.interval_ms == 1000
	assert !document.active_refresh_timer.is_active()
	assert state.calls == 0

	// Header refreshes become due only after completely-finished-loading.
	document.completely_finish_loading()
	assert document.active_refresh_timer.is_active()
	document.active_refresh_timer.fire()
	assert state.calls == 1
	assert state.url == 'https://example.test/next?x=1'
	assert !document.active_refresh_timer.is_active()
}

fn test_shared_declarative_refresh_rejects_javascript_and_overflow_defaults_to_zero() {
	mut rejected_state := &DeclarativeRefreshTestState{}
	mut rejected := refresh_test_document('https://example.test/', rejected_state)
	rejected.shared_declarative_refresh_steps('0; url=javascript:alert(1)')
	assert !rejected.will_declaratively_refresh
	assert rejected.active_refresh_timer == unsafe { nil }

	mut overflow_state := &DeclarativeRefreshTestState{}
	mut overflow := refresh_test_document('https://example.test/', overflow_state)
	overflow.shared_declarative_refresh_steps('2147484; /overflow')
	assert overflow.active_refresh_timer.interval_ms == 0
}

fn test_meta_declarative_refresh_starts_after_load_and_honors_sandbox() {
	mut state := &DeclarativeRefreshTestState{}
	mut document := refresh_test_document('https://example.test/', state)
	document.completely_loaded_time = true
	document.set_active_sandboxing_flag_bits(u32(512))
	document.shared_declarative_refresh_steps_for_meta('0; url=/blocked')

	assert document.active_refresh_timer.is_active()
	document.active_refresh_timer.fire()
	assert state.calls == 0
}
