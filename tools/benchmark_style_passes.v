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

import crypto.sha256
import css
import dom
import html
import os
import processmetrics
import time

fn main() {
	if os.args.len < 2 {
		panic('usage: benchmark_style_passes INLINE_HTML [passes] [full|insert|signatures|computed|parse] [document-url]')
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
	if mode == 'parse' {
		report_stylesheet_parsing(document, passes)
		return
	}
	body := document.body() or { panic('missing body') }
	mut body_node := unsafe { &dom.Node(body) }
	if mode == 'computed' {
		// The first style pass, then one inserted copy as `insert` styles it.
		mut container := document.create_element('div') or { panic(err) }
		mut container_node := container.as_node()
		for child in body_node.children {
			copy := child.clone_node(none, true, none) or { panic(err) }
			container_node.append_child(copy) or { panic(err) }
		}
		body_node.append_child(container_node) or { panic(err) }
		document.update_style()
		report_computed_style_digest(document)
		return
	}
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
	mut computer := css.css_style_computer_for(document)
	scope := css.style_scope_for_dom_node(document.as_node())
	// The ancestor filter must hold each element's ancestors, as during a
	// style pass; otherwise every rule with ancestor hashes is rejected.
	mut pushed := []&dom.Element{}
	mut seen := map[string]int{}
	mut with_environment := map[string]int{}
	mut total := 0
	// Stable across processes: sheet and rule indexes, specificity and the
	// restyle bits, in document order, for comparing bucketing controls.
	mut stable := []string{}
	mut with_inline := 0
	for element in css.query_selector_all(document.as_node(), '*') {
		mut chain := []&dom.Element{}
		mut parent := element.as_node().parent_element()
		for {
			ancestor := parent or { break }
			chain.prepend(ancestor)
			parent = ancestor.as_node().parent_element()
		}
		mut common := 0
		for common < pushed.len && common < chain.len && voidptr(pushed[common]) == voidptr(chain[common]) {
			common++
		}
		for pushed.len > common {
			computer.pop_ancestor(pushed.pop())
		}
		for ancestor in chain[common..] {
			computer.push_ancestor(ancestor)
			pushed << ancestor
		}
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
		mut stable_parts := []string{}
		for rule in set.user_agent_rules {
			stable_parts << '${rule.rule.style_sheet_index}.${rule.rule.rule_index}.${rule.rule.specificity}'
		}
		for layer in set.author_rules {
			stable_parts << layer.qualified_layer_name
			for rule in layer.rules {
				stable_parts << '${rule.rule.style_sheet_index}.${rule.rule.rule_index}.${rule.rule.specificity}'
			}
		}
		// Whether the coarse query lets each generated pseudo-element cascade.
		mut pseudo_candidates := []bool{}
		dom_pseudos := [dom.PseudoElement.before, .after, .selection, .first_letter, .first_line, .marker]
		css_pseudos := [css.PseudoElement.before, .after, .selection, .first_letter, .first_line, .marker]
		for index, pseudo in dom_pseudos {
			pseudo_abstract := dom.AbstractElement.new(element, pseudo)
			pseudo_candidates << scope.has_indexed_candidate_rule_for_pseudo_element(pseudo_abstract, css_pseudos[index])
		}
		stable << '${stable_parts.join(',')}|${attempted.get(.hover)}${attempted.get(.focus)}${attempted.get(.focus_within)}${attempted.get(.focus_visible)}${attempted.get(.target)}|${pseudo_candidates}'
		if element.has_attribute('style') { with_inline++ }
		seen[parts.join(',')]++
		// With the custom property environment the cascade resolves var() in.
		environment := if data := abstract.custom_property_data() { u64(voidptr(data)) } else { u64(0) }
		with_environment['${parts.join(',')}#${environment}']++
		total++
	}
	for pushed.len > 0 {
		computer.pop_ancestor(pushed.pop())
	}
	mut repeated := 0
	for _, count in seen { if count > 1 { repeated += count - 1 } }
	mut repeated_in_environment := 0
	for _, count in with_environment { if count > 1 { repeated_in_environment += count - 1 } }
	println('matched-rule digest ${sha256.hexhash(stable.join('\n'))}')
	println('signatures elements=${total} distinct=${seen.len} repeats=${repeated} repeat_rate=${f64(repeated) / f64(total):.2f} inline_style=${with_inline} environment_distinct=${with_environment.len} environment_repeat_rate=${f64(repeated_in_environment) / f64(total):.2f}')
}

// Every element's computed longhands, serialized in document order: compares
// style reuse controls against the ordinary computation.
fn report_computed_style_digest(document &dom.Document) {
	mut lines := []string{}
	mut empty := 0
	mut present := 0
	for element in css.query_selector_all(document.as_node(), '*') {
		computed := css.up_to_date_computed_properties_for_element(element)
		mut parts := []string{cap: css.number_of_longhand_properties}
		for index in 0 .. css.number_of_longhand_properties {
			value := computed.raw_property_at_index(index)
			if value == unsafe { nil } {
				parts << '-'
				continue
			}
			present++
			if value.css_text == '' { empty++ }
			parts << value.css_text
		}
		lines << parts.join('|')
	}
	println('computed-style digest ${sha256.hexhash(lines.join('\n'))} elements=${lines.len} values=${present} empty_text=${empty}')
}

// The page's style sheets parsed again, as a stylesheet response is parsed
// when it arrives (large sheets' declarations are parsed later, on first use).
// Run with VOX_DISABLE_STYLESHEET_RULE_CACHE=1: repeated texts otherwise reuse
// their raw rules and only conversion is measured.
fn report_stylesheet_parsing(document &dom.Document, passes int) {
	mut texts := []string{}
	for element in css.query_selector_all(document.as_node(), 'style') {
		texts << element.as_node().text_content() or { '' }
	}
	mut bytes := 0
	for text in texts { bytes += text.len }
	mut best_instructions := u64(0)
	mut best_ns := u64(0)
	mut rules := 0
	for _ in 0 .. passes {
		start := time.sys_mono_now()
		before := processmetrics.thread_instruction_snapshot()
		rules = 0
		for text in texts {
			sheet := css.parse_owner_style_sheet_text(document, text, 'https://github.githubassets.com/assets/bench.css')
			rules += sheet.rules.length()
		}
		instructions := processmetrics.thread_instruction_snapshot().since(before) or { 0 }
		elapsed := time.sys_mono_now() - start
		if best_instructions == 0 || instructions < best_instructions { best_instructions = instructions }
		if best_ns == 0 || elapsed < best_ns { best_ns = elapsed }
	}
	println('mode=parse sheets=${texts.len} bytes=${bytes} rules=${rules} passes=${passes} best_ms=${f64(best_ns) / 1e6:.1f} best_instructions=${best_instructions} instructions_per_byte=${f64(best_instructions) / f64(bytes):.1f}')
}
