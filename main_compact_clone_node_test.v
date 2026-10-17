module main

import browserjs
import html

// 4chan copies its board navigation to the page foot with cloneNode(true),
// renames ids inside the copy and inserts it, then gives each board list a
// clone of a script-created menu control.
fn test_compact_clone_node_copies_and_inserts_detached_elements() {
	$if !darwin {
		return
	}
	mut document := html.parse_document('<!doctype html><html><body><div id="nav" class="desktop"><span class="boardList">[<a href="/a/">a</a>]</span><span id="navtopright">[<a href="/search">Search</a>]</span></div><div id="threads"></div><div id="absbot"></div></body></html>')
	mut runtime := browserjs.Runtime.create()
	defer {
		runtime.close()
	}
	mut messages := []string{}
	run_document_javascript(document, 'https://boards.4chan.org/pol/catalog', [r'
		const nav = document.getElementById("nav");
		const copy = nav.cloneNode(true);
		copy.id = nav.id + "Foot";
		const right = copy.querySelector("#navtopright");
		right.id = "navbotright";
		document.body.insertBefore(copy, document.getElementById("absbot"));
		const shallow = nav.cloneNode();
		const control = document.createElement("span");
		control.className = "custom-menu-ctrl";
		control.innerHTML = "[<a href=\"#\">Edit</a>]";
		const lists = document.getElementsByClassName("boardList");
		lists[0].appendChild(control);
		const second = control.cloneNode(true);
		lists[1].appendChild(second);
		globalThis.result = [copy.id, right.id, shallow.id, shallow.hasChildNodes(), copy === nav,
			second === control, second.className, lists.length].join("|");
	'], runtime, mut messages)
	assert runtime.evaluate_host('result')! == 'navFoot|navbotright|nav|false|false|false|custom-menu-ctrl|2'
	assert messages == []
	foot := document.get_element_by_id('navFoot') or { panic('missing cloned navigation') }
	next := foot.as_node().next_element_sibling() or { panic('missing foot sibling') }
	assert next.get_attribute_value('id') == 'absbot'
	assert (document.get_element_by_id('navtopright') or { panic('missing top links') }).as_node().parent_element()?.get_attribute_value('id') == 'nav'
	assert (document.get_element_by_id('navbotright') or { panic('missing foot links') }).as_node().parent_element()?.get_attribute_value('id') == 'navFoot'
	body := document.body() or { panic('missing body') }
	body_html := body.inner_html()!
	assert body_html.count('custom-menu-ctrl') == 2
	assert body_html.count('>Edit<') == 2
	nav := document.get_element_by_id('nav') or { panic('missing navigation') }
	assert (nav.inner_html()!).count('>Edit<') == 1
	assert (foot.inner_html()!).count('>Edit<') == 1
}
