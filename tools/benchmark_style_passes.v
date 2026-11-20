// Component benchmark of document style passes on a frozen page: the first
// style of the parsed document; repeated full style updates of the same DOM
// (`full`, elements compared with their previous style); and repeated first
// styles of a deep copy of the body's content inserted into the styled page
// (`insert`, as a script inserting rendered content). Use it to profile
// per-element style cost without layout, scripts or the browser. Input is HTML
// with its style sheets inlined as <style> elements.
//
// Build it like the browser (production compiler, `-prod -prealloc -gc none`,
// the receipt's `-path`), not with FastC: TinyCC code has other hot spots.
//   benchmark_style_passes page.html 20 insert
module main

import css
import dom
import html
import os
import time

fn main() {
	if os.args.len < 2 {
		panic('usage: benchmark_style_passes INLINE_HTML [passes] [full|insert] [document-url]')
	}
	markup := os.read_file(os.args[1]) or { panic(err) }
	passes := if os.args.len > 2 { os.args[2].int() } else { 10 }
	mode := if os.args.len > 3 { os.args[3] } else { 'full' }
	document_url := if os.args.len > 4 { os.args[4] } else { 'https://github.com/' }
	mut document := html.parse_document_with_url(markup, dom.URL{ value: document_url })
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	document.set_viewport_rect(dom.Rect{ width: 1280, height: 800 })
	mut computer := css.css_style_computer_for(document)
	computer.set_animation_time_ms(0)
	elements := css.query_selector_all(document.as_node(), '*').len
	first_start := time.sys_mono_now()
	document.update_style()
	first_ns := time.sys_mono_now() - first_start
	body := document.body() or { panic('missing body') }
	mut body_node := unsafe { &dom.Node(body) }
	mut styled := elements
	mut total_ns := u64(0)
	mut best_ns := u64(0)
	for _ in 0 .. passes {
		mut copies := []&dom.Node{}
		if mode == 'insert' {
			mut container := document.create_element('div') or { panic(err) }
			mut container_node := container.as_node()
			for child in body_node.children {
				copy := child.clone_node(none, true, none) or { panic(err) }
				container_node.append_child(copy) or { panic(err) }
			}
			body_node.append_child(container.as_node()) or { panic(err) }
			copies << container_node
			styled = css.query_selector_all(container_node, '*').len + 1
		} else {
			document.set_needs_full_style_update(true)
		}
		start := time.sys_mono_now()
		document.update_style()
		elapsed := time.sys_mono_now() - start
		for mut copy in copies { copy.remove(false) }
		total_ns += elapsed
		if best_ns == 0 || elapsed < best_ns { best_ns = elapsed }
	}
	average_ns := if passes > 0 { total_ns / u64(passes) } else { u64(0) }
	println('mode=${mode} elements=${elements} styled=${styled} first_ms=${f64(first_ns) / 1e6:.1f} passes=${passes} average_ms=${f64(average_ns) / 1e6:.1f} best_ms=${f64(best_ns) / 1e6:.1f} best_us_per_element=${f64(best_ns) / 1e3 / f64(styled):.2f}')
}
