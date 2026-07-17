module layout

import dom
import css

fn computed_style_for(doc &dom.Document, tag string, style string) &css.ComputedProperties {
	mut el := doc.create_element_ns('http://www.w3.org/1999/xhtml', tag) or { panic('${err}') }
	if style.len > 0 {
		el.set_attribute_value('style', style)
	}
	s := css.css_style_computer_for(doc)
	return s.compute_style(dom.AbstractElement.new(el, none))
}

// Box-model edges resolve from the computed style; an auto-width block fills its containing block minus
// its own margins/border/padding (CSS 2.1 §10.3.3).
fn test_block_width_auto() {
	doc := dom.Document.create(dom.url_about_blank())
	computed := computed_style_for(doc, 'div', 'padding: 10px')

	mut uv := &UsedValues{}
	resolve_box_model_edges(computed, mut uv, 200.0)
	assert uv.padding_left.to_double() == 10.0
	assert uv.padding_right.to_double() == 10.0

	compute_block_used_width(computed, mut uv, 200.0)
	// auto width: 200 - 0 margins - 0 border - (10 + 10) padding = 180
	assert uv.content_width().to_double() == 180.0
	assert uv.has_definite_width()
}

// A definite-width block with `margin: auto` on both sides is centered in its containing block.
fn test_block_width_definite_auto_margins() {
	doc := dom.Document.create(dom.url_about_blank())
	computed := computed_style_for(doc, 'div', 'width: 100px; margin-left: auto; margin-right: auto')

	mut uv := &UsedValues{}
	resolve_box_model_edges(computed, mut uv, 300.0)
	compute_block_used_width(computed, mut uv, 300.0)

	assert uv.content_width().to_double() == 100.0
	// Remaining 300 - 100 = 200 split evenly.
	assert uv.margin_left.to_double() == 100.0
	assert uv.margin_right.to_double() == 100.0
}

// A percentage width resolves against the containing block width.
fn test_block_width_percentage() {
	doc := dom.Document.create(dom.url_about_blank())
	computed := computed_style_for(doc, 'div', 'width: 50%')

	mut uv := &UsedValues{}
	resolve_box_model_edges(computed, mut uv, 400.0)
	compute_block_used_width(computed, mut uv, 400.0)
	assert uv.content_width().to_double() == 200.0
}

// End-to-end block flow: build a layout tree from the DOM and lay it out — children stack vertically and
// the container's auto height is the sum of their heights.
fn test_block_flow_vertical_layout() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut div1 := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	div1.set_attribute_value('style', 'height: 30px')
	mut div2 := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	div2.set_attribute_value('style', 'height: 40px')

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(div1.as_node()) or { panic('${err}') }
	html_node.append_child(div2.as_node()) or { panic('${err}') }

	root := build_layout_tree(doc) or { panic('no layout tree') }
	viewport := root.as_viewport() or { panic('root not a Viewport') }

	mut state := LayoutState.new()
	layout_viewport(mut state, viewport, 800.0, 600.0)

	// html: auto width fills 800; auto height = 30 + 40 = 70.
	html_box := root.first_child() or { panic('no html box') }
	html_nws := html_box.as_node_with_style() or { panic('html not nws') }
	html_uv := state.try_get(html_nws) or { panic('no html used values') }
	assert html_uv.content_width().to_double() == 800.0
	assert html_uv.content_height().to_double() == 70.0

	div1_nws := html_box.children()[0].as_node_with_style() or { panic('div1 not nws') }
	div2_nws := html_box.children()[1].as_node_with_style() or { panic('div2 not nws') }
	div1_uv := state.try_get(div1_nws) or { panic('no div1 used values') }
	div2_uv := state.try_get(div2_nws) or { panic('no div2 used values') }

	// Divs fill the width, keep their definite heights, and stack: div1 at y=0, div2 at y=30.
	assert div1_uv.content_width().to_double() == 800.0
	assert div1_uv.content_height().to_double() == 30.0
	assert div2_uv.content_height().to_double() == 40.0
	assert div1_uv.offset.y().to_double() == 0.0
	assert div2_uv.offset.y().to_double() == 30.0
}

// max-width clamps an auto (filling) width; min-width raises a too-small width.
fn test_width_min_max_clamp() {
	doc := dom.Document.create(dom.url_about_blank())

	max_computed := computed_style_for(doc, 'div', 'max-width: 100px')
	mut max_uv := &UsedValues{}
	resolve_box_model_edges(max_computed, mut max_uv, 400.0)
	compute_block_used_width(max_computed, mut max_uv, 400.0)
	assert max_uv.content_width().to_double() == 100.0 // would fill 400, clamped to 100

	min_computed := computed_style_for(doc, 'div', 'width: 50px; min-width: 120px')
	mut min_uv := &UsedValues{}
	resolve_box_model_edges(min_computed, mut min_uv, 400.0)
	compute_block_used_width(min_computed, mut min_uv, 400.0)
	assert min_uv.content_width().to_double() == 120.0 // 50 raised to min 120
}

// min-height raises an empty box's auto height; max-height caps a tall box.
fn test_height_min_max_clamp() {
	doc := dom.Document.create(dom.url_about_blank())

	min_computed := computed_style_for(doc, 'div', 'min-height: 100px')
	mut min_box := NodeWithStyle.new(doc, none, min_computed)
	mut state1 := LayoutState.new()
	layout_block_flow(mut state1, min_box, 800.0, none)
	min_uv := state1.try_get(min_box) or { panic('no min-height used values') }
	assert min_uv.content_height().to_double() == 100.0 // auto 0 raised to min 100

	parent_computed := computed_style_for(doc, 'div', 'max-height: 60px')
	child_computed := computed_style_for(doc, 'div', 'height: 100px')
	mut parent := NodeWithStyle.new(doc, none, parent_computed)
	mut child := NodeWithStyle.new(doc, none, child_computed)
	parent.append_child(unsafe { &Node(child) })
	mut state2 := LayoutState.new()
	layout_block_flow(mut state2, parent, 800.0, none)
	parent_uv := state2.try_get(parent) or { panic('no parent used values') }
	assert parent_uv.content_height().to_double() == 60.0 // child 100 capped to max 60
	child_uv := state2.try_get(child) or { panic('no child used values') }
	assert child_uv.content_height().to_double() == 100.0 // child itself not clamped
}

// Adjacent siblings' vertical margins collapse (CSS 2.1 §8.3.1): the gap is the larger margin, not the sum.
fn test_adjacent_margin_collapse() {
	mut doc := dom.Document.create(dom.url_about_blank())
	mut html_el := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'html') or { panic('${err}') }
	mut div1 := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	div1.set_attribute_value('style', 'height: 10px; margin-bottom: 20px')
	mut div2 := doc.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic('${err}') }
	div2.set_attribute_value('style', 'height: 10px; margin-top: 30px')

	mut doc_node := unsafe { &dom.Node(doc) }
	doc_node.append_child(html_el.as_node()) or { panic('${err}') }
	mut html_node := html_el.as_node()
	html_node.append_child(div1.as_node()) or { panic('${err}') }
	html_node.append_child(div2.as_node()) or { panic('${err}') }

	root := build_layout_tree(doc) or { panic('no layout tree') }
	viewport := root.as_viewport() or { panic('root not a Viewport') }
	mut state := LayoutState.new()
	layout_viewport(mut state, viewport, 800.0, 600.0)

	html_box := root.first_child() or { panic('no html box') }
	div1_uv := state.try_get(html_box.children()[0].as_node_with_style() or { panic('d1') }) or { panic('uv1') }
	div2_uv := state.try_get(html_box.children()[1].as_node_with_style() or { panic('d2') }) or { panic('uv2') }

	assert div1_uv.offset.y().to_double() == 0.0
	// div1 bottom = 10; collapsed margin = max(20, 30) = 30; div2 at 10 + 30 = 40 (NOT 10+20+30=60).
	assert div2_uv.offset.y().to_double() == 40.0
}

// A percentage height resolves against the containing block's definite height (CSS 2.1 §10.5).
fn test_percentage_height() {
	doc := dom.Document.create(dom.url_about_blank())
	parent_computed := computed_style_for(doc, 'div', 'height: 200px')
	child_computed := computed_style_for(doc, 'div', 'height: 50%')
	mut parent := NodeWithStyle.new(doc, none, parent_computed)
	mut child := NodeWithStyle.new(doc, none, child_computed)
	parent.append_child(unsafe { &Node(child) })
	mut state := LayoutState.new()
	layout_block_flow(mut state, parent, 800.0, none)

	parent_uv := state.try_get(parent) or { panic('no parent used values') }
	assert parent_uv.content_height().to_double() == 200.0
	child_uv := state.try_get(child) or { panic('no child used values') }
	assert child_uv.content_height().to_double() == 100.0 // 50% of the parent's 200px
}

// A percentage height against an indefinite (auto) containing-block height is treated as auto.
fn test_percentage_height_indefinite_containing_block() {
	doc := dom.Document.create(dom.url_about_blank())
	parent_computed := computed_style_for(doc, 'div', '') // auto height
	child_computed := computed_style_for(doc, 'div', 'height: 50%')
	mut parent := NodeWithStyle.new(doc, none, parent_computed)
	mut child := NodeWithStyle.new(doc, none, child_computed)
	parent.append_child(unsafe { &Node(child) })
	mut state := LayoutState.new()
	layout_block_flow(mut state, parent, 800.0, none)

	child_uv := state.try_get(child) or { panic('no child used values') }
	// Indefinite CB height -> % height is auto -> the empty child's content height is 0.
	assert child_uv.content_height().to_double() == 0.0
}
