module main

import css
import dom
import gg
import page

fn javascript_navigation_app(markup string) !&BrowserApp {
	mut owner := page.Page.create(1)!
	mut app := &BrowserApp{
		page_model:      owner
		script_policy:   .enabled
		viewport_width:  320
		viewport_height: 200
	}
	app.install_loaded_page(LoadedPage{
		url:          'https://old.reddit.com/r/test/comments/fixture/thread/'
		content_type: 'text/html'
		markup:       '<!doctype html>' + markup
	}, false)
	return app
}

fn javascript_navigation_click(mut app BrowserApp, target &dom.Element) {
	// This windowless fixture dispatches CSS-pixel coordinates independently
	// of the native display's backing scale.
	mut document := app.document
	document.set_layout_coordinate_scale(1)
	rect := target.get_bounding_client_rect()
	x := rect.x + rect.width / 2
	y := rect.y + rect.height / 2
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, x, y)
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, x, y)
	// The native window defers navigation until its input work has finished.
	app.ctx = &gg.Context{}
	mut scope := app.begin_navigation_work()
	app.replay_compact_javascript_click()
	scope.finish()
}

fn test_comment_toggle_with_undefined_return_keeps_javascript_void_link_on_document() {
	mut app :=
		javascript_navigation_app('<div id="thing" class="collapsed"><a class="expand" href="javascript:void(0)" onclick="return togglecomment(this)">[+]</a></div><script>function togglecomment(control){thing.classList.replace("collapsed","noncollapsed");control.textContent="[-]";}</script>')!
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	link := css.query_selector(document.as_node(), '.expand')?
	javascript_navigation_click(mut app, link)
	app.poll_deferred_navigation_input()
	assert document.get_element_by_id('thing')?.get_attribute_value('class') == 'noncollapsed'
	assert link.as_node().text_content()? == '[-]'
	assert voidptr(app.document) == voidptr(document)
	assert app.address == 'https://old.reddit.com/r/test/comments/fixture/thread/'
	assert app.navigation_generation == 0
	assert app.pending_navigation == none
	assert app.deferred_navigation_input == none
	assert app.js_messages == []string{}
}

fn test_javascript_link_executes_percent_decoded_source_without_coercing_completion() {
	mut app :=
		javascript_navigation_app('<p id="comment">before</p><script>globalThis.coercions=0;</script>')!
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	app.navigate('javascript:comment.textContent%3D%22expanded%22;({toString(){coercions++;return "unexpected document";}})',
		true)
	assert document.get_element_by_id('comment')?.as_node().text_content()? == 'expanded'
	assert app.js_runtime.evaluate_host('coercions')! == '0'
	assert voidptr(app.document) == voidptr(document)
	assert app.navigation_generation == 0
	assert app.history.len == 0
}

fn test_javascript_link_respects_document_scripting_and_csp() {
	mut app :=
		javascript_navigation_app('<meta http-equiv="Content-Security-Policy" content="script-src &apos;none&apos;"><p id="comment">unchanged</p><script>globalThis.blockedScriptRan=true;</script>')!
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	app.navigate('javascript:comment.textContent="should not run"', true)
	assert document.get_element_by_id('comment')?.as_node().text_content()? == 'unchanged'
	assert voidptr(app.document) == voidptr(document)
	assert app.navigation_generation == 0
}

fn test_javascript_string_completion_replaces_markup_at_current_url_and_keeps_policy() {
	mut app :=
		javascript_navigation_app('<meta http-equiv="Content-Security-Policy" content="script-src &apos;unsafe-inline&apos;"><p>before</p><script>globalThis.ready=true;</script>')!
	mut original := app.document
	defer { original.finalize() }
	app.navigate('javascript:\'<p id="replacement">Привет</p>\'', true)
	mut replacement := app.document
	defer {
		if app.js_runtime != unsafe { nil } { app.js_runtime.close() }
		replacement.finalize()
	}
	assert voidptr(replacement) != voidptr(original)
	assert replacement.get_element_by_id('replacement')?.as_node().text_content()? == 'Привет'
	assert replacement.url == original.url
	assert replacement.origin().is_same_origin(original.origin())
	assert replacement.policy_container().csp_list.len == original.policy_container().csp_list.len
	assert app.history.len == 0
}
