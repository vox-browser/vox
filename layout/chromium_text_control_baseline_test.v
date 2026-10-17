module layout

import html

fn text_control_baseline(chromium bool) f64 {
	mut document := html.parse_document('<!doctype html><style>body { margin:0; font:13.333333px Arial }
		input { margin:0; border:1px solid #aaa; padding:0 2px; font:13.333333px Arial; height:16px;
			line-height:16px; width:120px; -webkit-appearance:none }</style>
		<div><input id="search" placeholder="Search OPs…"> [<a>Catalog</a>]</div>')
	if chromium {
		document.set_font_rendering_policy(.chromium)
	}
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	input := text_control_baseline_find(result.root, 'search') or { panic('missing input') }
	return layout_box_baseline(result.state, input, .last).to_double()
}

fn text_control_baseline_find(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id {
				return root
			}
		}
	}
	for child in root.children() {
		if found := text_control_baseline_find(child, id) {
			return found
		}
	}
	return none
}

// 4chan's thread search box: Brave aligns the text after a single-line text
// control with the baseline of the control's editor text, although that
// internal editor is a scroll container.
fn test_text_control_baseline_ignores_editor_overflow_under_chromium_policy() {
	// The 16px line box holds the 15px Arial content area at its top, so the
	// baseline is the 1px border plus Arial's 12px rounded ascent.
	assert text_control_baseline(true) == 13
	// LibWeb keeps the editor's bottom-edge baseline as a scroll container.
	assert text_control_baseline(false) == 17
}

fn toggle_control_baseline(chromium bool, type_ string) f64 {
	mut document := html.parse_document('<!doctype html><style>body { margin:0; font:13.333333px Arial }</style>
		<div><input id="toggle" type="${type_}"> label</div>')
	if chromium {
		document.set_font_rendering_policy(.chromium)
	}
	result := run_document_layout(document, 800, 600) or { panic('layout failed') }
	input := text_control_baseline_find(result.root, 'toggle') or { panic('missing input') }
	return layout_box_baseline(result.state, input, .last).to_double()
}

// 4chan's post headers: a check box's 3px bottom margin hangs below the
// baseline in Blink, so the following text stays level with its border box.
fn test_chromium_toggle_controls_align_their_border_box_with_the_baseline() {
	// Blink's html.css margins: 3px 3px 3px 4px and 3px 3px 0 5px.
	assert toggle_control_baseline(true, 'checkbox') == 16
	// LibWeb's margin-free check box uses its bottom edge.
	assert toggle_control_baseline(false, 'checkbox') == 13
	// Only the radio button's 3px top margin lies above its border box.
	assert toggle_control_baseline(true, 'radio') == toggle_control_baseline(false, 'radio') + 3
}
