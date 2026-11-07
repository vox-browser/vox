module main

import dom
import html
import platform

fn favicon_discovery_app(address string, markup string) &BrowserApp {
	mut document := dom.Document.create(dom.URL{ value: address })
	html.parse_html_from_a_string(document, '<!doctype html><html><head>${markup}</head><body></body></html>')
	return &BrowserApp{ document: document }
}

fn favicon_discovery_expect(app &BrowserApp, declared string, fallback string) {
	actual, default_url := app.browser_tab_favicon_urls()
	assert actual == declared
	assert default_url == fallback
}

fn test_favicon_discovery_invalidates_link_edits_tree_order_and_live_base() {
	mut app := favicon_discovery_app('https://site.example/path/page',
		'<base id="base" href="https://cdn.example/assets/"><link id="first" rel="icon" href="a.png"><link id="last" rel="shortcut ICON" href="b.png">')
	defer { app.document.finalize() }
	fallback := 'https://site.example/favicon.ico'
	favicon_discovery_expect(app, 'https://cdn.example/assets/b.png', fallback)
	mut first := app.document.get_element_by_id('first') or { panic('first') }
	mut last := app.document.get_element_by_id('last') or { panic('last') }
	last.set_attribute_value('href', 'c.png')
	favicon_discovery_expect(app, 'https://cdn.example/assets/c.png', fallback)
	last.set_attribute_value('rel', 'stylesheet')
	favicon_discovery_expect(app, 'https://cdn.example/assets/a.png', fallback)
	last.set_attribute_value('rel', 'ICON')
	last.remove_attribute('href')
	favicon_discovery_expect(app, 'https://cdn.example/assets/a.png', fallback)
	mut attributes := last.attributes()
	attributes.set_attribute(&dom.Attr_{ name_: 'href', local_name_: 'href', value_: 'd.png' })!
	favicon_discovery_expect(app, 'https://cdn.example/assets/d.png', fallback)
	mut head := (app.document.head() or { panic('head') }).as_node()
	head.append_child(first.as_node())!
	favicon_discovery_expect(app, 'https://cdn.example/assets/a.png', fallback)
	mut first_node := first.as_node()
	first_node.remove(false)
	favicon_discovery_expect(app, 'https://cdn.example/assets/d.png', fallback)
	mut body := (app.document.body() or { panic('body') }).as_node()
	body.append_child(last.as_node())!
	favicon_discovery_expect(app, '', fallback)
	head.append_child(last.as_node())!
	mut base := app.document.get_element_by_id('base') or { panic('base') }
	base.set_attribute_value('href', 'https://other.example/')
	favicon_discovery_expect(app, 'https://other.example/d.png', fallback)
}

fn test_favicon_discovery_tracks_document_url_about_base_encoding_and_empty_results() {
	mut app := favicon_discovery_app('https://site.example/one/page', '<link rel="icon" href="image.png">')
	defer { app.document.finalize() }
	favicon_discovery_expect(app, 'https://site.example/one/image.png', 'https://site.example/favicon.ico')
	app.document.set_url(dom.URL{ value: 'https://next.example/two/page' })
	favicon_discovery_expect(app, 'https://next.example/two/image.png', 'https://next.example/favicon.ico')
	app.document.set_url(dom.url_about_blank())
	app.document.about_base_url = dom.URL{ value: 'https://parent.example/one/' }
	favicon_discovery_expect(app, 'https://parent.example/one/image.png', '')
	app.document.about_base_url = dom.URL{ value: 'https://parent.example/two/' }
	favicon_discovery_expect(app, 'https://parent.example/two/image.png', '')
	app.document.set_encoding('windows-1251')
	favicon_discovery_expect(app, 'https://parent.example/two/image.png', '')
	if !disable_tab_favicon_discovery_cache {
		assert app.browser_text_cache().favicon_discovery_encoding == 'windows-1251'
	}
	mut head := (app.document.head() or { panic('head') }).as_node()
	head.remove(false)
	favicon_discovery_expect(app, '', '')
	favicon_discovery_expect(app, '', '')
}

fn test_favicon_discovery_owns_results_after_caller_and_old_document_retire() {
	mut app := favicon_discovery_app('https://site.example/path/page', '<link rel="icon" href="image.png">')
	mut caller := platform.new_arena('favicon discovery caller')
	entry := caller.enter()
	declared, fallback := app.browser_tab_favicon_urls()
	cache := app.browser_text_cache()
	if !disable_tab_favicon_discovery_cache {
		assert !caller.contains(voidptr(cache))
		assert !caller.contains(declared.str) && !caller.contains(fallback.str)
		assert !caller.contains(cache.favicon_discovery_document_url.str)
		assert !caller.contains(cache.favicon_discovery_base_url.str)
		assert !caller.contains(cache.favicon_discovery_encoding.str)
	}
	caller.leave(entry)
	caller.reset()
	caller.release()
	mut old := app.document
	app.document = dom.Document.create(dom.url_about_blank())
	old.finalize()
	defer { app.document.finalize() }
	if !disable_tab_favicon_discovery_cache {
		assert declared == 'https://site.example/path/image.png'
		assert fallback == 'https://site.example/favicon.ico'
	}
	favicon_discovery_expect(app, '', '')
}

fn test_warm_favicon_discovery_avoids_per_frame_allocations() {
	markup := '<link rel="preload stylesheet" href="unused.css">'.repeat(300)
	mut app := favicon_discovery_app('https://site.example/path/page', '${markup}<link rel="icon" href="image.png">')
	defer { app.document.finalize() }
	favicon_discovery_expect(app, 'https://site.example/path/image.png', 'https://site.example/favicon.ico')
	before := platform.thread_arena_usage().used
	for _ in 0 .. 128 {
		favicon_discovery_expect(app, 'https://site.example/path/image.png', 'https://site.example/favicon.ico')
	}
	$if prealloc {
		if !disable_tab_favicon_discovery_cache {
			assert platform.thread_arena_usage().used == before
		}
	}
}

fn test_unrelated_attribute_edits_do_not_retain_duplicate_discovery_strings() {
	mut app := favicon_discovery_app('https://site.example/path/page', '<link rel="icon" href="image.png">')
	defer { app.document.finalize() }
	mut root := app.document.document_element() or { panic('root') }
	for _ in 0 .. 4 {
		favicon_discovery_irrelevant_edit(app, mut root)
	}
	before := platform.thread_arena_usage().used
	for _ in 0 .. 128 {
		favicon_discovery_irrelevant_edit(app, mut root)
	}
	$if prealloc {
		if !disable_tab_favicon_discovery_cache {
			assert platform.thread_arena_usage().used - before < 1024
		}
	}
}

fn favicon_discovery_irrelevant_edit(app &BrowserApp, mut root dom.Element) {
	mut allocations := app.document.enter_native_storage()
	root.set_attribute_value('data-discovery-test', 'unchanged icon')
	allocations.finish()
	mut scratch := platform.begin_thread_scratch('unrelated favicon edit')
	favicon_discovery_expect(app, 'https://site.example/path/image.png', 'https://site.example/favicon.ico')
	scratch.finish()
}
