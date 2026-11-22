// Component benchmark of document layout passes on a frozen page: the first
// style and layout of the parsed document, then repeated small mutations of
// the kinds a hydrating page makes, each followed by one layout update. Use
// it to measure and profile per-pass layout cost without scripts, network or
// the browser's frame loop. Input is HTML with its style sheets inlined as
// <style> elements (the style pass benchmark's input).
//
// Build it like the browser (production compiler, `-prod -prealloc -gc none`,
// the receipt's `-path`).
//   benchmark_layout_passes page.html 20 head
//
// VOX_BENCHMARK_LAYOUT_SCALE=2 lays out in device pixels at that scale.
//
// Modes: full (rebuild the whole layout tree), head (insert an element into
// <head>), class (toggle a class on one element inside the page), text (change
// one text node's value, as React updates text), insert (append a small element
// to VOX_BENCHMARK_INSERT_SELECTOR's element, then remove it), record (record the
// viewport display list again without a change). VOX_BENCHMARK_CLASS_SELECTOR
// chooses the class mode's element and VOX_BENCHMARK_CLASS_ATTRIBUTE=name=value
// the attribute it toggles.
module main

import css
import dom
import html
import layout
import os
import processmetrics
import time

fn main() {
	if os.args.len < 2 {
		panic('usage: benchmark_layout_passes INLINE_HTML [passes] [full|head|class|insert|text] [document-url]')
	}
	markup := os.read_file(os.args[1]) or { panic(err) }
	passes := if os.args.len > 2 { os.args[2].int() } else { 10 }
	mode := if os.args.len > 3 { os.args[3] } else { 'full' }
	document_url := if os.args.len > 4 { os.args[4] } else { 'https://github.com/vlang/v' }
	mut document := html.parse_document_with_url(markup, dom.URL{ value: document_url })
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	document.set_viewport_rect(dom.Rect{ width: 1024, height: 768 })
	// The browser lays out in device pixels when capturing at a device pixel
	// ratio (the GitHub benchmark captures at 2).
	if scale := os.getenv_opt('VOX_BENCHMARK_LAYOUT_SCALE') {
		document.set_layout_coordinate_scale(scale.f64())
	}
	layout.enable_native_paint_tree_storage(document)
	layout.install_document_layout_hook(document)
	mut computer := css.css_style_computer_for(document)
	computer.set_animation_time_ms(0)
	elements := css.query_selector_all(document.as_node(), '*').len
	first_start := time.sys_mono_now()
	first_counted := processmetrics.thread_instruction_snapshot()
	document.update_layout(.debugging)
	first_instructions := processmetrics.thread_instruction_snapshot().since(first_counted) or { 0 }
	first_ns := time.sys_mono_now() - first_start
	if layout.document_layout_result(document) == none {
		panic('the first update produced no layout')
	}
	mut head := document.head() or { panic('missing head') }
	// The first paragraph with a box and a text child: a hidden one would not
	// need any layout.
	mut target := unsafe { &dom.Element(nil) }
	mut text_target := ?&dom.Node(none)
	for paragraph in css.query_selector_all(document.as_node(), 'p') {
		if paragraph.as_node().unsafe_layout_node() == none { continue }
		for child in paragraph.as_node().children {
			if child.is_text() && child.unsafe_layout_node() != none {
				text_target = child
				break
			}
		}
		if text_target != none {
			target = paragraph
			break
		}
	}
	if target == unsafe { nil } { panic('no laid out paragraph with text') }
	// The class mode's element: VOX_BENCHMARK_CLASS_SELECTOR picks another one
	// (for example the react-app element that React marks as loaded).
	mut class_target := target
	mut insert_target := class_target
	if selector := os.getenv_opt('VOX_BENCHMARK_INSERT_SELECTOR') {
		insert_target = css.query_selector(document.as_node(), selector) or { panic('no ${selector}') }
	}
	// VOX_BENCHMARK_CLASS_ATTRIBUTE=name=value toggles another attribute.
	attribute_setting := os.getenv('VOX_BENCHMARK_CLASS_ATTRIBUTE')
	class_attribute := if attribute_setting != '' { attribute_setting.all_before('=') } else { 'class' }
	class_value := if attribute_setting.contains('=') { attribute_setting.all_after('=') } else { 'benchmark-toggle' }
	if selector := os.getenv_opt('VOX_BENCHMARK_CLASS_SELECTOR') {
		class_target = css.query_selector(document.as_node(), selector) or { panic('no ${selector}') }
	}
	mut best_ns := u64(0)
	mut best_instructions := u64(0)
	mut total_instructions := u64(0)
	for pass in 0 .. passes {
		match mode {
			'full' {
				document.set_needs_full_layout_tree_update(true)
			}
			'head' {
				mut link := document.create_element('link') or { panic(err) }
				link.set_attribute_value('rel', 'preload')
				link.set_attribute_value('href', 'https://github.githubassets.com/assets/bench-${pass}.js')
				link.set_attribute_value('as', 'script')
				mut head_node := head.as_node()
				head_node.append_child(link.as_node()) or { panic(err) }
			}
			'class' {
				if pass % 2 == 0 {
					class_target.set_attribute_value(class_attribute, class_value)
				} else {
					class_target.remove_attribute(class_attribute)
				}
			}
			'insert' {
				// A small element appended to VOX_BENCHMARK_INSERT_SELECTOR's
				// element (default the class mode's), removed on odd passes.
				mut parent := insert_target.as_node()
				if pass % 2 == 0 {
					mut inserted := document.create_element('div') or { panic(err) }
					inserted.set_attribute_value('class', 'benchmark-inserted')
					mut inserted_node := inserted.as_node()
					inserted_node.append_child(document.create_text_node('inserted').as_node()) or { panic(err) }
					parent.append_child(inserted_node) or { panic(err) }
				} else {
					mut last := parent.last_child() or { panic('no child') }
					last.remove(false)
				}
			}
			'text' {
				mut node := text_target or { panic('no text node') }
				// As React updates text: the node's value, not textContent.
				node.set_node_value('benchmark text ${pass}') or { panic(err) }
			}
			'record' {}
			else {
				panic('unknown mode ${mode}')
			}
		}
		start := time.sys_mono_now()
		counted := processmetrics.thread_instruction_snapshot()
		if mode == 'record' {
			// Re-recording the viewport display list of an unchanged laid-out
			// document, as an animation frame that changes only paint does.
			document.set_needs_repaint()
			_ = document.record_viewport_display_list()
		} else {
			document.update_layout(.debugging)
		}
		instructions := processmetrics.thread_instruction_snapshot().since(counted) or { 0 }
		elapsed := time.sys_mono_now() - start
		total_instructions += instructions
		if best_ns == 0 || elapsed < best_ns { best_ns = elapsed }
		if best_instructions == 0 || instructions < best_instructions { best_instructions = instructions }
	}
	println('mode=${mode} elements=${elements} first_ms=${f64(first_ns) / 1e6:.1f} first_instructions=${first_instructions} passes=${passes} best_ms=${f64(best_ns) / 1e6:.2f} best_instructions=${best_instructions} average_instructions=${if passes > 0 { total_instructions / u64(passes) } else { 0 }}')
}
