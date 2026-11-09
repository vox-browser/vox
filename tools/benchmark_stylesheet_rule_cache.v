// Component benchmark of the production owner-node stylesheet parser on a
// frozen page. Timers exclude file I/O, validation, finalization and explicit
// pre-sample GC; automatic collection during parsing/styling remains included.
// JavaScript hydration, network, layout, paint and browser startup are excluded.
module main

import crypto.sha256
import css
import dom
import html
import json2
import layout
import os
import strings
import time

struct Sample {
	iteration       int
	parse_ns        i64
	style_ns        i64
	sheets          int
	rules           int
	elements        int
	styled_elements int
	longhands       int
	validated       bool
	cssom_sha256    string
	computed_sha256 string
	layout_sha256   string
}

fn count_rules(list &css.CSSRuleList) int {
	mut count := list.rules.len
	for rule in list.rules {
		if children := rule.rules { count += count_rules(children) }
	}
	return count
}

fn measure(markup string, document_url string, iteration int, validate bool, layout_output string) Sample {
	start := time.sys_mono_now()
	mut document := html.parse_document_with_url(markup, dom.URL{ value: document_url })
	parse_end := time.sys_mono_now()
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.set_navigable(&dom.Navigable{ active_document_: document })
	document.set_viewport_rect(dom.Rect{ width: 1280, height: 800 })
	mut computer := css.css_style_computer_for(document)
	computer.set_animation_time_ms(0)
	style_start := time.sys_mono_now()
	document.update_style()
	style_end := time.sys_mono_now()
	mut sheet_count := 0
	mut rule_count := 0
	mut cssom := strings.new_builder(2_000_000)
	for element in css.query_selector_all(document.as_node(), 'style') {
		if sheet := css.style_element_sheet(element) {
			sheet_count++
			rule_count += count_rules(sheet.rules)
			if validate {
				cssom.writeln('sheet:${sheet_count}')
				for rule in sheet.rules.rules { cssom.writeln(rule.css_text()) }
			}
		}
	}
	mut computed := strings.new_builder(1_000_000)
	elements := css.query_selector_all(document.as_node(), '*')
	mut styled := 0
	first_longhand := int(css.first_longhand_property_id())
	last_longhand := int(css.last_longhand_property_id())
	for index, element in elements {
		if validate { computed.writeln('${index}:${element.local_name()}') }
		if properties := css.computed_properties_for_element(element) {
			styled++
			if !validate { continue }
			for property_index in first_longhand .. last_longhand + 1 {
				property := unsafe { css.PropertyID(property_index) }
				if value := properties.property(property, .yes) {
					computed.writeln(value.css_text)
				} else {
					computed.writeln('<none>')
				}
			}
		} else if validate {
			computed.writeln('<unstyled>')
		}
	}
	mut layout_digest := ''
	if validate && layout_output != '' {
		// Optional geometry validation is deliberately outside every timer and
		// runs only after the last sample. No transport or scripts are installed.
		tree := layout.dump_document_layout_tree(document, 1280, 800) or {
			panic('failed to build document layout tree')
		}
		os.write_file(layout_output, tree) or { panic(err) }
		layout_digest = sha256.hexhash(tree)
	}
	return Sample{
		iteration:       iteration
		parse_ns:        parse_end - start
		style_ns:        style_end - style_start
		sheets:          sheet_count
		rules:           rule_count
		elements:        elements.len
		styled_elements: styled
		longhands:       last_longhand - first_longhand + 1
		validated:       validate
		cssom_sha256:    if validate { sha256.hexhash(cssom.str()) } else { '' }
		computed_sha256: if validate { sha256.hexhash(computed.str()) } else { '' }
		layout_sha256:   layout_digest
	}
}

fn main() {
	if os.args.len < 2 {
		panic('usage: benchmark_stylesheet_rule_cache INLINE_HTML [repeat-count] [document-url] [layout-output]')
	}
	markup := os.read_file(os.args[1]) or { panic(err) }
	repeats := if os.args.len > 2 { os.args[2].int() } else { 2 }
	document_url := if os.args.len > 3 { os.args[3] } else { 'https://github.com/' }
	layout_output := if os.args.len > 4 { os.args[4] } else { '' }
	for iteration in 0 .. repeats + 1 {
		gc_collect()
		// CSSOM serialization materializes unused declarations. Do it only
		// after the final timed parse, so it cannot warm a later iteration.
		sample := measure(markup, document_url, iteration, iteration == repeats, layout_output)
		println(json2.encode(sample))
	}
}
