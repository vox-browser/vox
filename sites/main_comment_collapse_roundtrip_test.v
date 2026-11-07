module main

import css
import dom
import gg
import page

fn test_comment_tree_collapses_and_expands_without_replacing_document() {
	mut owner := page.Page.create(1)!
	mut app := &BrowserApp{
		page_model:      owner
		script_policy:   .enabled
		viewport_width:  320
		viewport_height: 200
	}
	markup := '<!doctype html><style>.collapsed > .entry > .usertext,.collapsed > .child{display:none}</style><div id="thing" class="comment noncollapsed"><div class="entry"><a class="expand" href="javascript:void(0)" onclick="return togglecomment(this)">[–]</a><div class="usertext">Parent comment</div></div><div class="child"><p id="reply">Nested reply</p></div></div><script>globalThis.toggles=0;function togglecomment(control){toggles++;const thing=control.closest(".comment");const collapsed=thing.classList.contains("collapsed");thing.classList.remove(collapsed?"collapsed":"noncollapsed");thing.classList.add(collapsed?"noncollapsed":"collapsed");control.textContent=collapsed?"[–]":"[+]";}</script>'
	app.install_loaded_page(LoadedPage{
		url:          'https://old.reddit.com/r/test/comments/thread/'
		content_type: 'text/html'
		markup:       markup
	}, true)
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	link := css.query_selector(document.as_node(), '.expand')?
	body := css.query_selector(document.as_node(), '.usertext')?
	reply := document.get_element_by_id('reply')?
	assert body.get_bounding_client_rect().height > 0
	assert reply.get_bounding_client_rect().height > 0
	for turn in 0 .. 2 {
		rect := link.get_bounding_client_rect()
		assert rect.height > 0
		x := rect.x + rect.width / 2
		y := rect.y + rect.height / 2
		_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, x, y)
		_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, x, y)
		app.ctx = &gg.Context{}
		mut scope := app.begin_navigation_work()
		app.replay_compact_javascript_click()
		scope.finish()
		app.poll_deferred_navigation_input()
		assert app.document == document
		assert app.address == 'https://old.reddit.com/r/test/comments/thread/'
		assert app.history.len == 1
		assert app.history_index == 0
		assert app.navigation_generation == 0
		assert app.pending_navigation == none
		assert app.deferred_navigation_input == none
		assert app.js_runtime.evaluate_host('toggles')! == (turn + 1).str()
		if turn == 0 {
			assert link.as_node().text_content()? == '[+]'
			assert body.get_bounding_client_rect().height == 0
			assert reply.get_bounding_client_rect().height == 0
		} else {
			assert link.as_node().text_content()? == '[–]'
			assert body.get_bounding_client_rect().height > 0
			assert reply.get_bounding_client_rect().height > 0
		}
		assert app.js_messages == []string{}
	}
}
