module main

import browserjs
import css
import dom
import gg
import html
import layout
import page

// HN deliberately shares each row's ID with its collapse anchor. Keep the
// archived site script (identical to hn.js on the reported page) so its
// delegated listener and traversal run together.
fn hacker_news_collapse_label_rect(box &layout.BlockBox, target &dom.Element) ?dom.Rect {
	for line in box.lines {
		for fragment in line.fragments {
			if fragment.inline_node_id != i64(target.as_node().unique_id()) { continue }
			rect := fragment.paintable_fragment.absolute_rect()
			if rect.width > 0 && rect.height > 0 {
				return dom.Rect{rect.x, rect.y, rect.width, rect.height}
			}
		}
	}
	for child in box.children {
		if rect := hacker_news_collapse_label_rect(child, target) { return rect }
	}
	return none
}

fn hacker_news_collapse_click(mut app BrowserApp, target &dom.Element) {
	// Click the rendered glyphs, converting device-layout units to CSS pixels.
	rect := hacker_news_collapse_label_rect(app.root_box, target) or { panic('missing collapse label') }
	scale := app.document.layout_coordinate_scale()
	x := (rect.x + rect.width / 2) / scale
	y := (rect.y + rect.height / 2) / scale
	hit := app.hit_test_at_viewport_point(x, y) or { panic('missing collapse hit') }
	assert voidptr(hit.element) == voidptr(target)
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, x, y)
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, x, y)
	app.ctx = &gg.Context{}
	mut scope := app.begin_navigation_work()
	app.replay_compact_javascript_click()
	scope.finish()
	app.poll_deferred_navigation_input()
	settings := unsafe { &html.EnvironmentSettingsObject(app.document.relevant_settings_object()) }
	if global_scope := settings.window_or_worker_global_scope() {
		assert global_scope.reported_errors().len == 0
	}
}

fn test_hacker_news_comment_collapse_roundtrip_from_pointer_input() {
	mut owner := page.Page.create(1)!
	mut app := &BrowserApp{
		page_model:      owner
		script_policy:   .enabled
		viewport_width:  800
		viewport_height: 600
	}
	mut markup := '<!doctype html><style>.noshow{display:none}.nosee{visibility:hidden}</style><table><tbody>'
	for index, indent in [0, 1, 2, 1, 0] {
		id := (50348485 + index).str()
		markup += '<tr class="athing comtr" id="${id}"><td><table><tr><td class="ind" indent="${indent}"></td><td class="votelinks">vote</td><td class="default"><div style="margin-top:2px;margin-bottom:-10px"><span class="comhead"><span class="navs"><a class="togg clicky" id="${id}" n="4" href="javascript:void(0)">[–]</a></span></span></div><br><div class="comment">Comment ${index}</div></td></tr></table></td></tr>'
	}
	markup += '</tbody></table><script>' + $embed_file('@VMODROOT/Tests/Browser/Brave/hn-home-instructions/bodies/2e38ff883bd36dc4cc26f129f19169b0357cf32059988c926a4f73e5bfaa37f0').to_string() + '</script>'
	app.install_loaded_page(LoadedPage{
		url:          'https://news.ycombinator.com/item?id=50345924'
		content_type: 'text/html'
		markup:       markup
	}, true)
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	assert app.js_messages == []string{}
	link := css.query_selector(document.as_node(), '.togg')?
	rows := css.query_selector_all(document.as_node(), '.comtr')
	body := css.query_selector(rows[0].as_node(), '.comment')?
	for turn in 0 .. 2 {
		hacker_news_collapse_click(mut app, link)
		assert app.js_messages == []string{}
		assert rows[0].class_names().contains('coll') == (turn == 0), app.js_runtime.evaluate_host('JSON.stringify({row:document.querySelector(".comtr").className,label:document.querySelector(".togg").getBoundingClientRect(),body:document.querySelector(".comment").getBoundingClientRect()})')!
		assert link.as_node().text_content()? == if turn == 0 { '[4 more]' } else { '[–]' }
		assert (body.get_bounding_client_rect().height == 0) == (turn == 0)
		for row in rows[1..4] {
			assert (row.get_bounding_client_rect().height == 0) == (turn == 0)
		}
		assert rows[4].get_bounding_client_rect().height > 0
		assert voidptr(app.document) == voidptr(document)
		assert app.address == 'https://news.ycombinator.com/item?id=50345924'
		assert app.history.len == 1
		assert app.navigation_generation == 0
		assert app.pending_navigation == none
		assert app.deferred_navigation_input == none
	}
	// Expanding a parent must preserve an independently collapsed reply.
	child_link := css.query_selector(rows[1].as_node(), '.togg')?
	hacker_news_collapse_click(mut app, child_link)
	assert rows[1].class_names().contains('coll')
	assert rows[2].get_bounding_client_rect().height == 0
	hacker_news_collapse_click(mut app, link)
	hacker_news_collapse_click(mut app, link)
	assert rows[1].get_bounding_client_rect().height > 0
	assert rows[1].class_names().contains('coll')
	assert rows[2].get_bounding_client_rect().height == 0
	assert rows[3].get_bounding_client_rect().height > 0
	hacker_news_collapse_click(mut app, child_link)
	assert rows[2].get_bounding_client_rect().height > 0
	assert app.navigation_generation == 0
	assert app.js_messages == []string{}
}

fn test_compact_native_window_click_handler_runs_once_and_honors_propagation() {
	mut document := html.parse_document('<!doctype html><button id="control">click</button>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://news.ycombinator.com/', [r'
globalThis.clickOrder=[];
control.addEventListener("click",()=>clickOrder.push("control"));
document.addEventListener("click",()=>clickOrder.push("document"));
window.onclick=function(event){clickOrder.push("window");if(!(event instanceof MouseEvent)||event.currentTarget!==window)throw new Error("native window click");return false;};
'], runtime, mut messages)
	state := runtime.evaluate_host('__ladybirdDispatch("click","control")')!
	assert javascript_default_prevented(state)
	assert runtime.evaluate_host('clickOrder.join(",")')! == 'control,document,window'
	runtime.evaluate_host('clickOrder=[];document.addEventListener("click",event=>event.stopImmediatePropagation());')!
	stopped := runtime.evaluate_host('__ladybirdDispatch("click","control")')!
	assert !javascript_default_prevented(stopped)
	assert runtime.evaluate_host('clickOrder.join(",")')! == 'control,document'
	assert messages == []string{}
}
