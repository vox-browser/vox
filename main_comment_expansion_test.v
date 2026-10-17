module main

import css
import dom
import gg
import page

fn comment_expansion_app(markup string) !&BrowserApp {
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

fn comment_expansion_click(mut app BrowserApp, target &dom.Element) {
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

fn test_comment_expansion_runs_idless_inline_handler_and_cancels_link() {
	mut app :=
		comment_expansion_app('<div id="thing"><a class="expand" href="javascript:void(0)" onclick="return togglecomment(this)">[+]</a><p id="comment" style="display:none">Expanded comment</p></div><script>globalThis.expansions=0;function togglecomment(control){expansions++;control.textContent="[-]";comment.style.display="block";return false;}</script>')!
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	link := css.query_selector(document.as_node(), '.expand')?
	comment_expansion_click(mut app, link)
	assert app.js_runtime.evaluate_host('expansions')! == '1'
	assert link.as_node().text_content()? == '[-]'
	assert document.get_element_by_id('comment')?.get_bounding_client_rect().height > 0
	assert app.pending_native_navigation == none
	assert app.deferred_navigation_input == none
	assert app.navigation_generation == 0
	assert app.js_messages == []string{}
}

fn test_comment_expansion_bubbles_from_nested_idless_label_to_delegated_listener() {
	mut app :=
		comment_expansion_app('<section id="comments"><div id="thing"><a class="expand" href="/unwanted-navigation"><b>expand</b></a><p id="comment" hidden>Expanded comment</p></div></section><script>globalThis.clickOrder=[];thing.addEventListener("click",function(event){clickOrder.push(event.target.textContent);});comments.addEventListener("click",function(event){if(event.target.closest(".expand")){clickOrder.push("comments");comment.hidden=false;event.preventDefault();}});</script>')!
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	label := css.query_selector(document.as_node(), '.expand b')?
	comment_expansion_click(mut app, label)
	assert app.js_runtime.evaluate_host('clickOrder.join(",")')! == 'expand,comments'
	assert !document.get_element_by_id('comment')?.has_attribute('hidden')
	assert app.deferred_navigation_input == none
	assert app.navigation_generation == 0
	assert app.js_messages == []string{}
}

fn test_comment_link_keeps_destination_through_deferred_native_input_and_collection() {
	mut app :=
		comment_expansion_app('<div id="thing"><a class="comments" href="/r/test/comments/next/thread/">more comments</a></div><script>thing.addEventListener("click",function(){thing.className="access-required";});</script>')!
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	link := css.query_selector(document.as_node(), '.comments')?
	comment_expansion_click(mut app, link)
	assert app.navigation_generation == 0
	assert app.deferred_navigation_input?.address == 'https://old.reddit.com/r/test/comments/next/thread/'
	gc_collect()
	app.poll_deferred_navigation_input()
	assert app.pending_navigation?.resolved == 'https://old.reddit.com/r/test/comments/next/thread/'
	assert app.deferred_navigation_input == none
	assert app.navigation_generation == 1
}

fn test_comment_click_script_navigation_supersedes_deferred_link_default() {
	mut app :=
		comment_expansion_app('<a id="expand" href="/unwanted-navigation">more comments</a><script>expand.addEventListener("click",function(){location.href="/r/test/comments/next/thread/?context=3";});</script>')!
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	comment_expansion_click(mut app, document.get_element_by_id('expand')?)
	assert app.navigation_generation == 0
	assert app.deferred_navigation_input?.address == 'https://old.reddit.com/r/test/comments/next/thread/?context=3'
	app.poll_deferred_navigation_input()
	assert app.pending_navigation?.resolved == 'https://old.reddit.com/r/test/comments/next/thread/?context=3'
	assert app.navigation_generation == 1
}
