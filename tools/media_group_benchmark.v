// Retired-instruction component on unchanged archived CSS and synthetic grouping
// shapes. Parsing, first evaluation, state checks and process startup are excluded.
module main

import css
import dom
import os
import processmetrics

fn match_checksum(rules &css.CSSRuleList) u64 {
	mut result := u64(17)
	for rule in rules.rules {
		if rule.type_ == .media {
			result = result * 31 + u64(if rule.did_evaluate { 2 } else { 0 })
				+ u64(if rule.condition_matches() { 1 } else { 0 })
		}
		if children := rule.rules { result = result * 31 + match_checksum(children) }
	}
	return result
}

fn scene(name string, sources []string, rebuild bool) {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_viewport_rect(dom.Rect{width:1024, height:768})
	document.set_display_device_pixel_ratio(2)
	mut sheets := []&css.CSSStyleSheet{}
	mut expected := []u64{}
	for source in sources {
		mut sheet := css.parse_css_stylesheet_with_parser(source, none)
		sheet.evaluate_media_queries(document)
		expected << match_checksum(sheet.rules)
		sheets << sheet
	}
	iterations := if rebuild { 32 } else { 256 }
	mut changes := 0
	start := processmetrics.instruction_snapshot()
	for _ in 0 .. iterations {
		for mut sheet in sheets {
			if rebuild { sheet.rules.set_rules(sheet.rules.rules.clone()) }
			if sheet.evaluate_media_queries(document) { changes++ }
		}
	}
	instructions := processmetrics.instruction_snapshot().since(start) or {
		panic('instruction counter unavailable')
	}
	assert changes == 0
	mut checksum := u64(0)
	for index, sheet in sheets {
		actual := match_checksum(sheet.rules)
		assert actual == expected[index]
		checksum = checksum * 31 + actual
	}
	println('{"scene":"${name}","instructions":${instructions},"evaluations":${iterations * sheets.len},"changes":${changes},"checksum":${checksum}}')
}

fn main() {
	if os.args.len != 2 { panic('expected a file containing archived CSS paths') }
	mut sources := []string{}
	for path in os.read_lines(os.args[1]) or { panic(err) } {
		sources << os.read_file(path) or { panic(err) }
	}
	assert sources.len > 0
	scene('archived-warm', sources, false)
	scene('archived-rebuild', sources, true)
	flat := '@media (min-width:600px) {}'.repeat(32)
	deep := '@layer a {'.repeat(12) + flat + '}'.repeat(12)
	oversized := '@layer a {'.repeat(12) + '@media (min-width:600px) {}'.repeat(257)
		+ '}'.repeat(12)
	scene('flat-warm', [flat], false)
	scene('deep-warm', [deep], false)
	scene('deep-rebuild', [deep], true)
	scene('oversized-warm', [oversized], false)
	scene('oversized-rebuild', [oversized], true)
}
