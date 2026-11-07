module main

import layout
import page
import html
import dom

fn test_native_navigation_reclaims_payload_after_final_scene_reader() {
	mut owner := page.Page.create(1)!
	mut app := BrowserApp{page_model: owner, script_policy: .disabled,
		viewport_width: 320, viewport_height: 240}
	// Cross the syntax-cache threshold, then retire the source document before
	// a later navigation reuses its cached immutable tokenizer input.
	markup := '<!doctype html><style>/*' + 'shared parser input '.repeat(260)
		+ '*/ p { color: red; background:linear-gradient(white, blue) }</style><p>First page</p><input placeholder="Text">'
	app.install_loaded_page(LoadedPage{url: 'https://storage.example/first', markup: markup,
		content_type: 'text/html'}, true)
	storage := app.document.native_storage()
	scene := layout.retain_display_list_scene(app.paint_display_list)
	commands := app.paint_commands
	app.install_loaded_page(LoadedPage{url: 'https://storage.example/second',
		markup: markup.replace('First page', 'Second page'), content_type: 'text/html'}, true)
	assert commands.any(it.text.contains('First page'))
	$if prealloc { assert storage.arena.usage().used > 0 }
	// Parser completion is deliberately an unassociated task: it must observe
	// the now-inactive document before dropping its final asynchronous lease.
	mut event_loop := html.main_thread_event_loop()
	event_loop.process()
	layout.release_display_list_scene(scene)
	$if prealloc { assert storage.arena.usage().used == 0 }
	assert app.paint_commands.any(it.text.contains('Second page'))
	app.install_loaded_page(LoadedPage{url: 'https://storage.example/third',
		markup: markup.replace('First page', 'Third page'), content_type: 'text/html'}, true)
	assert app.paint_commands.any(it.text.contains('Third page'))
	assert app.document.navigable()?.active_document_is(app.document)
	app.dispose_browser_tab()
}

fn test_cross_document_adoption_keeps_the_native_source_storage_alive() {
	mut owner := page.Page.create(1)!
	mut app := BrowserApp{page_model: owner, script_policy: .disabled,
		viewport_width: 320, viewport_height: 240}
	app.install_loaded_page(LoadedPage{url: 'https://storage.example/source',
		markup: '<!doctype html><p id="adopted">Adopted content</p>', content_type: 'text/html'}, false)
	storage := app.document.native_storage()
	node := app.document.get_element_by_id('adopted')?.as_node()
	mut target := dom.Document.create(dom.url_about_blank())
	target.adopt_node(node)
	app.install_loaded_page(LoadedPage{url: 'https://storage.example/replacement',
		markup: '<!doctype html><p>Replacement</p>', content_type: 'text/html'}, false)
	mut event_loop := html.main_thread_event_loop()
	event_loop.process()
	assert node.text_content()? == 'Adopted content'
	$if prealloc { assert storage.arena.usage().used > 0 }
	app.dispose_browser_tab()
}
