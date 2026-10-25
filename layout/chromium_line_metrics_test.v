module layout

import html
import math

// Expected values were measured in Brave 1.97 (Chromium 155) on macOS.

fn test_browser_text_edge_atomic_boxes_do_not_raise_the_line_baseline() {
	$if macos {
		mut document := html.parse_document('<!doctype html><style>
			body { margin:0; font:24px/28px Arial }
			.line { width:450px }
			.small { font-size:20px; vertical-align:text-top }
			.box { display:inline-block; width:24px; height:24px }
			.top { vertical-align:text-top } .bottom { vertical-align:text-bottom }
		</style><div id="top" class="line"><span class="small">Heading</span><i class="box top"></i></div>
		<div id="bottom" class="line">Heading<i class="box bottom"></i></div>
		<div id="nested" class="line"><span class="small">Heading</span>&#8288;<span style="position:relative;top:2px">&#8288;<i class="box top"></i></span></div>')
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 1024, 768) or { panic('layout failed') }
		for id in ['top', 'bottom', 'nested'] {
			used := chromium_used_for_id(result, id)
			assert used.content_height().to_double() == 28, id
			assert used.line_boxes.len == 1
		}
	}
}

fn test_browser_text_edge_alignment_uses_the_parent_font() {
	$if macos {
		mut document := html.parse_document('<!doctype html><style>
			body { margin:0; font:20px/28px Arial }
			.line { width:450px }
			.top { vertical-align:text-top } .bottom { vertical-align:text-bottom }
			.small { font-size:16px } .big { font-size:24px }
			.box { display:inline-block; width:20px; height:10px }
		</style><div id="top" class="line">Hx<span class="top">Hx</span></div>
		<div id="bottom" class="line">Hx<span class="bottom">Hx</span></div>
		<div id="small" class="line">Hx<span class="top small">Hx</span></div>
		<div id="big" class="line">Hx<span class="top big">Hx</span></div>
		<div id="nested" class="line">Hx<span class="top small">Hx<span>Hx</span><i class="box top"></i></span></div>
		<div id="wrapped" style="width:80px"><span class="top">Heading heading</span></div>')
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 1024, 768) or { panic('layout failed') }
		for id in ['top', 'bottom', 'small', 'big', 'nested'] {
			assert chromium_used_for_id(result, id).content_height().to_double() == 31, id
		}
		for id, expected in {
			'top':    [3, 6]
			'bottom': [6, 3]
			'small':  [3, 8]
			'big':    [3, 3]
			'nested': [3, 8, 8, 8]
		} {
			fragments := chromium_used_for_id(result, id).line_boxes[0].fragments()
			assert fragments.len == expected.len, id
			for index, offset in expected {
				assert fragments[index].block_offset().to_double() == offset, '${id} fragment ${index}'
			}
		}
		wrapped := chromium_used_for_id(result, 'wrapped')
		assert wrapped.content_height().to_double() == 62
		assert wrapped.line_boxes.len == 2
		assert wrapped.line_boxes[0].fragments()[0].block_offset().to_double() == 6
		assert wrapped.line_boxes[1].fragments()[0].block_offset().to_double() == 37
	}
}

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

// Blink sizes a text node as one item even where fallback fonts and CJK
// break opportunities split it, rounding the item up to 1/64 px once.
// Widths were measured in Brave 1.97 (Chromium 155).
fn test_browser_fallback_split_text_nodes_round_once() {
	$if macos {
		mut document := html.parse_document('<!doctype html><style>body { margin:0; font:13px system-ui }</style>
			<div lang="zh"><span id="pair" style="display:inline-block">条目 / 條目</span></div>
			<div lang="zh"><span id="count" style="display:inline-block">1,559,000+ 条目 / 條目</span></div>
			<div lang="zh"><small id="portal" style="display:inline-block;font-size:13px">1,559,000+ <span>条目 / 條目</span></small></div>')
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		assert chromium_used_for_id(result, 'pair').content_width().to_double() == 64.09375
		assert chromium_used_for_id(result, 'count').content_width().to_double() == 136.015625
		// Wikipedia's portal: each text node is its own item, and the line that
		// shrink-to-fit sized must not wrap when measured chunk by chunk.
		portal := chromium_used_for_id(result, 'portal')
		assert portal.content_width().to_double() == 136.03125
		assert portal.line_boxes.len == 1
		// Glyphs after a font change keep the item's unsnapped pen positions.
		fragments := chromium_used_for_id(result, 'pair').line_boxes[0].fragments()
		origin := fragments[0].inline_offset_.to_double()
		mut checked := 0
		for fragment in fragments[1..] {
			run := fragment.glyph_run() or { continue }
			// SF runs start at their pen origin; PingFang's tracking offsets its first glyph.
			if run.font().family != 'SystemUi' {
				continue
			}
			mut pen := fragment.item_prefix_
			for glyph in run.glyphs() {
				x := fragment.inline_offset_.to_double() + f64(glyph.position.x)
				assert math.abs(x - origin - pen) < 0.0001
				pen += f64(glyph.advance)
			}
			checked++
		}
		assert checked == 1
	}
}

// With line-height: normal, fallback faces grow the line box with their own
// metrics and half line gaps, as measured in Brave: Hiragino's 8px gap makes a
// 16px Japanese line 24px tall, and PingFang's deeper descent makes 18px lines.
fn test_browser_normal_line_height_includes_fallback_fonts() {
	$if macos {
		mut document := html.parse_document('<!doctype html><style>body { margin:0; font-family:system-ui }</style>
			<div id="ja" lang="ja" style="font-size:16px">日本語の記事 / Japanese</div>
			<div id="zh" lang="zh" style="font-size:13px">1,559,000+ 条目 / 條目</div>
			<div id="ko" lang="ko" style="font-size:14px">한국어 위키백과 Korean</div>
			<div id="latin" style="font-size:16px">Latin only</div>')
		document.set_font_rendering_policy(.chromium)
		result := run_document_layout(document, 800, 600) or { panic('layout failed') }
		ja := chromium_used_for_id(result, 'ja')
		assert ja.content_height().to_double() == 24
		// The SF fragment keeps its 18px box, three pixels below the line top.
		assert ja.line_boxes[0].fragments()[0].block_offset().to_double() == 3
		assert chromium_used_for_id(result, 'zh').content_height().to_double() == 18
		assert chromium_used_for_id(result, 'ko').content_height().to_double() == 18
		assert chromium_used_for_id(result, 'latin').content_height().to_double() == 18
	}
}
