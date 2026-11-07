module main

import browserjs
import css
import dom
import gg
import html
import page

// Reddit's open/close functions and the menu portion of its body-click handler.
// The fixture is https://code.jquery.com/jquery-2.1.1.min.js, as in reddit-init.
const reddit_dropdown_script = r'
function open_menu(e){$(e).siblings(".drop-choices").not(".inuse").css("top",e.offsetHeight+"px").each(function(){$(this).css("left",$(e).position().left+"px").css("top",$(e).height()+$(e).position().top+"px")}).addClass("active inuse")}
function close_menu(e){$(e).closest(".drop-choices").removeClass("active inuse")}
function close_menus(e){$(".drop-choices.inuse").not(".active").removeClass("inuse"),$(".drop-choices.active").removeClass("active").trigger("close_menu")}
$("body").click(close_menus);
'

fn reddit_dropdown_click(mut app BrowserApp, element &dom.Element) {
	rect := element.get_bounding_client_rect()
	assert rect.width > 0 && rect.height > 0
	x := rect.x + rect.width / 2
	y := rect.y + rect.height / 2
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerdown', 0, x, y)
	_ = app.dispatch_chrome_pointer_event_at_viewport_point('pointerup', 0, x, y)
	app.ctx = &gg.Context{}
	mut scope := app.begin_navigation_work()
	app.replay_compact_javascript_click()
	scope.finish()
}

fn test_old_reddit_time_dropdown_opens_dismisses_and_reopens_from_its_label() {
	mut owner := page.Page.create(1)!
	mut app := &BrowserApp{
		page_model:      owner
		script_policy:   .enabled
		viewport_width:  400
		viewport_height: 300
	}
	markup :=
		'<!doctype html><style>body{margin:0;font:16px Arial}.menu{position:relative;margin:20px;padding:10px;border:2px solid black}.dropdown{display:inline-block;height:22px}.drop-choices{display:none;position:absolute;background:white;border:1px solid gray}.drop-choices.inuse{display:block}.choice{display:block}#outside{height:30px}</style><div class="menu">links from: <div class="dropdown" onclick="open_menu(this)"><span class="selected">all time</span></div>\n<!--between controls--><div class="drop-choices"><a class="choice" href="/search?q=france&amp;t=hour">past hour</a><a class="choice" href="/search?q=france&amp;t=day">past 24 hours</a></div></div><p id="outside">Outside the menu</p><script>' +
		$embed_file('@VMODROOT/Tests/Browser/fixtures/jquery-2.1.1.min.js').to_string() +
		'</script><script>' + reddit_dropdown_script + '</script>'
	app.install_loaded_page(LoadedPage{
		url:          'https://old.reddit.com/search?q=france'
		content_type: 'text/html'
		markup:       markup
	}, true)
	mut document := app.document
	defer {
		app.js_runtime.close()
		document.finalize()
	}
	label := css.query_selector(document.as_node(), '.selected')?
	menu := css.query_selector(document.as_node(), '.drop-choices')?
	assert menu.get_bounding_client_rect().height == 0
	assert app.js_messages == []string{}, app.js_messages.str()
	for turn in 0 .. 2 {
		reddit_dropdown_click(mut app, label)
		assert menu.get_attribute_value('class').contains('inuse'), app.js_messages.str()
		assert menu.get_bounding_client_rect().height > 0
		assert app.js_runtime.evaluate_host('(()=>{const control=document.querySelector(".dropdown"),menu=document.querySelector(".drop-choices"),rect=control.getBoundingClientRect(),box=menu.getBoundingClientRect();return Number.isFinite(parseFloat(menu.style.top))&&Number.isFinite(parseFloat(menu.style.left))&&Math.abs(box.top-rect.bottom)<1&&Math.abs(box.left-rect.left)<1;})()')! == 'true'
		assert app.document == document
		assert app.navigation_generation == 0
		assert app.js_messages == []string{}, app.js_messages.str()
		if turn == 0 {
			reddit_dropdown_click(mut app, document.get_element_by_id('outside')?)
			assert !menu.get_attribute_value('class').contains('inuse')
			assert menu.get_bounding_client_rect().height == 0
		}
	}
	choice := css.query_selector(menu.as_node(), '.choice')?
	reddit_dropdown_click(mut app, choice)
	assert app.deferred_navigation_input?.address == 'https://old.reddit.com/search?q=france&t=hour'
}

fn test_compact_first_child_and_siblings_follow_live_mixed_node_order() {
	mut document :=
		html.parse_document('<!doctype html><div id="host">text<!--comment--><b id="first">one</b>tail<i id="last">two</i></div><div id="empty"></div>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
		document.finalize()
	}
	mut messages := []string{}
	run_document_javascript(document, 'about:blank', [
		r'
const text=host.firstChild,comment=text.nextSibling;
if(text.nodeType!==3||text.data!=="text"||comment.nodeType!==8||comment.nextSibling!==first||first.previousSibling!==comment||first.nextSibling.data!=="tail"||last.nextSibling!==null||text.previousSibling!==null||empty.firstChild!==null)throw new Error("mixed sibling order");
host.insertBefore(last,first);
if(comment.nextSibling!==last||last.nextSibling!==first||first.previousSibling!==last)throw new Error("live sibling order");
last.remove();if(comment.nextSibling!==first||last.nextSibling!==null||last.previousSibling!==null)throw new Error("removed sibling order");
const range=document.createRange();range.setStart(text,1);range.setEnd(text,3);getSelection().addRange(range);
console.log("siblings passed");
',
	], runtime, mut messages)
	assert messages == ['siblings passed']
	selection := document.get_selection()?
	assert selection.anchor_offset() == 1
	assert selection.focus_offset() == 3
}
