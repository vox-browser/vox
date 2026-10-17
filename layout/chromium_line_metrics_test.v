module layout

import html

// Expected values were measured in Brave 1.97 (Chromium 155) on macOS.

fn chromium_layout_node_with_id(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := chromium_layout_node_with_id(child, id) {
			return found
		}
	}
	return none
}

fn chromium_used_for_id(result DocumentLayoutResult, id string) &UsedValues {
	node := chromium_layout_node_with_id(result.root, id) or { panic('missing #${id}') }
	styled := node.as_node_with_style() or { panic('#${id} has no style') }
	return result.used_values_for(styled) or { panic('#${id} has no used values') }
}

fn test_browser_line_boxes_follow_blink_metrics_and_leading() {
	$if macos {
		mut document := html.parse_document('<!doctype html><style>
			body { margin:0 }
			.middle { line-height:33px; font-size:32px; font-family:"Hoefler Text" }
			.middle span { display:inline-block; width:10px; height:32px; vertical-align:middle }
			#small { display:inline-block; font:13px/20.8px system-ui }
			#helvetica { font:16px Helvetica } #ui { font:13px system-ui } #hiragino { font:16px "Hiragino Kaku Gothic ProN" }
		</style>
		<div class="middle" id="bold" style="font-weight:700"><span></span></div>
		<div class="middle" id="regular"><span></span></div>
		<div><span id="small">7,249,000+</span></div>
		<div id="helvetica">Hxg</div><div id="ui">Hxg</div><div id="hiragino">Hxg</div>')
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		// Hoefler Text Black's rounded 23/9 metrics and truncated x-height make the
		// middle-aligned box protrude 5/64px above the strut.
		assert chromium_used_for_id(result, 'bold').content_height().to_double() == 33.078125
		assert chromium_used_for_id(result, 'regular').content_height().to_double() == 33
		assert chromium_used_for_id(result, 'small').content_height().to_double() == 20.796875
		// line-height: normal sums the rounded ascent, descent and line gap, with
		// the legacy 15% ascent adjustment for Helvetica.
		assert chromium_used_for_id(result, 'helvetica').content_height().to_double() == 18
		assert chromium_used_for_id(result, 'ui').content_height().to_double() == 16
		assert chromium_used_for_id(result, 'hiragino').content_height().to_double() == 24
	}
}

// A space after fallback CJK text is shaped with the primary font, as in
// Brave: SF's 3.58px space rather than PingFang's tracked 4.6px one.
fn test_browser_spaces_after_fallback_text_use_the_primary_font() {
	$if macos {
		mut document := html.parse_document('<!doctype html><style>body { margin:0; font:13px system-ui }</style>
			<div lang="zh"><span id="pair" style="display:inline-block">条目 / 條目</span></div>')
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		mut spaces := 0
		for fragment in chromium_used_for_id(result, 'pair').line_boxes[0].fragments() {
			run := fragment.glyph_run() or { continue }
			for glyph in run.glyphs() {
				if glyph.code_point == u32(` `) {
					assert run.font().family == 'SystemUi'
					spaces++
				}
			}
		}
		assert spaces == 2
	}
}
