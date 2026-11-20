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
import processmetrics
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
	if mode == 'signatures' {
		report_matched_rule_signatures(document)
		return
	}
	body := document.body() or { panic('missing body') }
	mut body_node := unsafe { &dom.Node(body) }
	mut styled := elements
	mut total_ns := u64(0)
	mut best_ns := u64(0)
	// Thread instructions are independent of other processes on the host.
	mut best_instructions := u64(0)
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
		counted := processmetrics.thread_instruction_snapshot()
		document.update_style()
		instructions := processmetrics.thread_instruction_snapshot().since(counted) or { 0 }
		elapsed := time.sys_mono_now() - start
		if best_instructions == 0 || instructions < best_instructions { best_instructions = instructions }
		for mut copy in copies { copy.remove(false) }
		total_ns += elapsed
		if best_ns == 0 || elapsed < best_ns { best_ns = elapsed }
	}
	average_ns := if passes > 0 { total_ns / u64(passes) } else { u64(0) }
	// With `-d vox_css_diagnostics`, the instruction and call counts per scope.
	css.report_diagnostic_instruction_scopes()
	println('mode=${mode} elements=${elements} styled=${styled} first_ms=${f64(first_ns) / 1e6:.1f} passes=${passes} average_ms=${f64(average_ns) / 1e6:.1f} best_ms=${f64(best_ns) / 1e6:.1f} best_us_per_element=${f64(best_ns) / 1e3 / f64(styled):.2f} best_instructions=${best_instructions} instructions_per_element=${best_instructions / u64(styled)}')
}

// How many elements match exactly the same author, user and user-agent rules
// (by identity, in cascade order) as an earlier element: the hit rate a cache
// keyed by matched rules could reach before inline styles and other inputs.
fn report_matched_rule_signatures(document &dom.Document) {
	computer := css.css_style_computer_for(document)
	scope := css.style_scope_for_dom_node(document.as_node())
	mut seen := map[string]int{}
	mut total := 0
	mut with_inline := 0
	for element in css.query_selector_all(document.as_node(), '*') {
		abstract := dom.AbstractElement.new(element, none)
		mut attempted := css.PseudoClassBitmap{}
		mut matched_pseudo := false
		set := css.style_computer_build_matching_rule_set_impl(computer, abstract, mut attempted,
			&matched_pseudo, .normal, scope)
		mut parts := []string{}
		for rule in set.user_agent_rules { parts << '${u64(voidptr(rule.rule))}' }
		parts << '|'
		for layer in set.author_rules {
			for rule in layer.rules { parts << '${u64(voidptr(rule.rule))}' }
			parts << '/'
		}
		if element.has_attribute('style') { with_inline++ }
		seen[parts.join(',')]++
		total++
	}
	mut repeated := 0
	for _, count in seen { if count > 1 { repeated += count - 1 } }
	println('signatures elements=${total} distinct=${seen.len} repeats=${repeated} repeat_rate=${f64(repeated) / f64(total):.2f} inline_style=${with_inline}')
}
