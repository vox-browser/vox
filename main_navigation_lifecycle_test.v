module main

import dom
import page

@[heap]
struct InactiveNavigationObservation {
mut:
	count int
}

fn test_replacing_native_document_releases_its_layout_and_notifies_inactivity_once() {
	owner := page.Page.create(1)!
	mut app := &BrowserApp{page_model: owner, script_policy: .disabled, viewport_width: 320, viewport_height: 200}
	app.install_loaded_page(LoadedPage{
		url: 'https://navigation-lifecycle.test/old'
		markup: '<!doctype html><p id="old">Old search results</p>'
	}, false)
	mut old := app.document
	old_element := old.get_element_by_id('old')?
	assert old.layout_root != unsafe { nil }
	assert old_element.as_node().unsafe_layout_node() != none
	observation := &InactiveNavigationObservation{}
	mut observer := dom.DocumentObserver.create(mut old)
	observer.set_document_became_inactive(fn [observation] () {
		mut state := unsafe { &InactiveNavigationObservation(observation) }
		state.count++
	})
	app.install_loaded_page(LoadedPage{
		url: 'https://navigation-lifecycle.test/new'
		markup: '<!doctype html><p id="new">New search results</p>'
	}, false)
	defer { observer.finalize(); app.document.finalize(); old.finalize() }
	assert !old.is_fully_active()
	assert old.layout_root == unsafe { nil }
	assert old_element.as_node().unsafe_layout_node() == none
	assert observation.count == 1
	assert app.document.is_fully_active()
	assert app.document.layout_root != unsafe { nil }
	assert app.paint_commands.any(it.text.contains('New search results'))
}
