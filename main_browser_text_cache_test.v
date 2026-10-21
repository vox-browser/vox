module main

import dom
import html
import platform

fn chrome_text_document(markup string) &dom.Document {
	mut document := dom.Document.create(dom.url_about_blank())
	html.parse_html_from_a_string(document, markup)
	return document
}

fn test_chrome_text_caches_title_mutations_replacement_and_fallbacks() {
	mut document := chrome_text_document('<!doctype html><title>First\nTitle</title>')
	mut other := chrome_text_document('<!doctype html><title>Other</title>')
	defer {
		document.finalize()
		other.finalize()
	}
	mut app := &BrowserApp{ document: document, address: 'https://title.test/' }
	assert app.browser_tab_title() == 'First Title'
	document.set_title('Second')!
	assert app.browser_tab_title() == 'Second'
	title := document.title_element() or { panic('missing title') }
	mut title_node := unsafe { &dom.Node(title) }
	mut text := title_node.first_child() or { panic('missing title text') }
	text.set_text_content('Changed directly')!
	assert app.browser_tab_title() == 'Changed directly'
	app.document = other
	assert app.browser_tab_title() == 'Other'
	other.set_title(' \r\n ')!
	assert app.browser_tab_title() == 'https://title.test/'
	app.document = unsafe { nil }
	app.address = 'about:blank'
	assert app.browser_tab_title() == 'New Tab'
}

fn test_unchanged_chrome_text_and_title_lists_allocate_no_frame_storage() {
	mut document := chrome_text_document('<!doctype html><title>Steady</title>')
	defer { document.finalize() }
	mut app := &BrowserApp{ document: document, js_messages: ['First line\r\nstack trace'] }
	first := app.browser_chrome_state(800, 600)
	assert first.footer == 'Console: First line'
	before := platform.thread_arena_usage().used
	for _ in 0 .. 1024 {
		state := app.browser_chrome_state(800, 600)
		assert state.footer == first.footer
		assert state.tab_titles == first.tab_titles
	}
	$if prealloc {
		assert platform.thread_arena_usage().used - before < 1024
	}
	app.js_messages[0] = 'Replacement\nnew stack'
	assert app.chrome_footer() == 'Console: Replacement'
	assert first.footer == 'Console: First line'
	document.set_title('New')!
	assert app.browser_chrome_state(800, 600).tab_titles == ['New']
	assert first.tab_titles == ['Steady']
}

fn test_chrome_text_cache_owns_values_read_during_temporary_paint_work() {
	mut document := chrome_text_document('<!doctype html><title>Owned</title>')
	defer { document.finalize() }
	mut app := &BrowserApp{ document: document, js_messages: ['Owned message\nstack'] }
	mut scratch := platform.new_arena('chrome text ownership fixture')
	entry := scratch.enter()
	first := app.browser_chrome_state(800, 600)
	scratch.leave(entry)
	scratch.reset()
	assert first.tab_titles == ['Owned']
	assert first.footer == 'Console: Owned message'
	assert app.browser_chrome_state(800, 600).tab_titles == first.tab_titles
	scratch.release()

	app.js_messages[0] = ''
	assert app.chrome_footer() == 'Console: '
	assert first.footer == 'Console: Owned message'
}
