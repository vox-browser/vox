module layout

import html
import math

struct TextBoxTrimSnapshot {
	height       f64
	width        f64
	baselines    []f64
	line_heights []f64
}

fn text_box_trim_snapshot(declaration string, markup string) TextBoxTrimSnapshot {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{font:12px/16px ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;width:220px;${declaration}}</style><div id="target">${markup}</div>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	mut pending := [result.root]
	for pending.len > 0 {
		node := pending.pop()
		if source := node.dom_node() {
			if element := source.as_element() {
				if element.get_attribute_value('id') == 'target' {
					used := result.used_values_for(node.as_node_with_style() or { panic('style') }) or { panic('used') }
					mut baselines := []f64{}
					mut heights := []f64{}
					for line in used.line_boxes {
						first := line.fragments_[0]
						baselines << first.block_offset().plus(first.baseline()).to_double()
						heights << line.height().to_double()
					}
					return TextBoxTrimSnapshot{used.content_height().to_double(), used.content_width().to_double(), baselines, heights}
				}
			}
		}
		pending << node.children()
	}
	panic('missing target')
}

fn test_text_box_trim_uses_cap_metrics_and_preserves_line_to_line_baselines() {
	$if !macos {
		return
	}
	markup := '<span>Upper case</span><br><a>Second line</a>'
	ordinary := text_box_trim_snapshot('', markup)
	start := text_box_trim_snapshot('text-box-trim:trim-start;text-box-edge:cap alphabetic', markup)
	end := text_box_trim_snapshot('text-box-trim:trim-end;text-box-edge:cap alphabetic', markup)
	both := text_box_trim_snapshot('text-box-trim:trim-both;text-box-edge:cap alphabetic', markup)
	assert ordinary.height == 32
	assert both.width == ordinary.width
	assert both.baselines.len == 2
	assert both.baselines[1] - both.baselines[0] == 16
	assert math.abs(end.height - ordinary.baselines[1]) < 0.02
	assert both.height == start.height + end.height - ordinary.height
	assert both.height == both.baselines[1]
	assert both.baselines == start.baselines
	assert both.height > 24 && both.height < 25
	assert both.line_heights[0] + both.line_heights[1] == both.height
}

fn test_text_box_trim_is_not_inherited_by_nested_blocks() {
	ordinary := text_box_trim_snapshot('', '<div>One</div><div>Two</div>')
	trimmed := text_box_trim_snapshot('text-box-trim:trim-both;text-box-edge:cap alphabetic', '<div>One</div><div>Two</div>')
	// Block-child propagation is a separate slice; never trim every child by
	// accidentally making text-box-trim an inherited property.
	assert trimmed.height == ordinary.height
}

fn test_trimmed_first_line_snaps_its_original_paint_origin_after_moving_with_the_text() {
	$if !macos { return }
	mut document := html.parse_document('<!doctype html><style>body{margin:0}p{position:absolute;top:80.453125px;left:20px;width:764px;margin:0;padding:8px 0;font:12px/16px ui-sans-serif,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;text-box-trim:trim-start;text-box-edge:cap alphabetic}</style><p>Capital text<br>Second line</p>')
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	root := layout_document_typed_in_viewport(document,800,600)
	commands := root.paint_commands().filter(it.kind=='draw_text' && it.glyph_run!=none)
	assert commands.len == 2
	assert commands[0].glyph_translation_y == 97
	assert commands[1].glyph_translation_y == 113
}
