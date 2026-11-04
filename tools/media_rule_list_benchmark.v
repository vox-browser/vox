// Component diagnostic on archived CSS, excluding parsing and startup.
module main

import css
import dom
import os
import processmetrics

fn count_media_children(rules &css.CSSRuleList) (int, int) {
	mut lists, mut empty := 0, 0
	for rule in rules.rules {
		if children := rule.rules {
			lists++
			if children.rules.len == 0 { empty++ }
			child_lists, child_empty := count_media_children(children)
			lists += child_lists
			empty += child_empty
		}
	}
	return lists, empty
}

fn main() {
	if os.args.len != 2 { panic('expected a file containing archived CSS paths') }
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_viewport_rect(dom.Rect{0, 0, 1024, 768})
	document.set_display_device_pixel_ratio(2)
	mut sheets := []&css.CSSStyleSheet{}
	mut lists, mut empty := 0, 0
	for path in os.read_lines(os.args[1]) or { panic(err) } {
		mut sheet := css.parse_css_stylesheet_with_parser(os.read_file(path) or { panic(err) }, none)
		child_lists, child_empty := count_media_children(sheet.rules)
		lists += child_lists
		empty += child_empty
		sheet.evaluate_media_queries(document)
		sheets << sheet
	}
	assert sheets.len > 0 && empty > 0
	mut changes := 0
	start := processmetrics.instruction_snapshot()
	for _ in 0 .. 256 {
		for mut sheet in sheets {
			if sheet.evaluate_media_queries(document) { changes++ }
		}
	}
	instructions := processmetrics.instruction_snapshot().since(start) or { panic('instruction counter unavailable') }
	assert changes == 0
	println('{"instructions":${instructions},"evaluations":${256 * sheets.len},"sheets":${sheets.len},"child_lists":${lists},"empty_lists":${empty},"changes":${changes}}')
}
