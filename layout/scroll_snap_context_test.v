module layout

import css
import dom
import html

fn snap_context_computed_style(declaration string) (&dom.Document, &css.ComputedValues) {
	document := dom.Document.create(dom.url_about_blank())
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	element.set_attribute_value('style', declaration)
	mut computer := css.StyleComputer.new(document)
	computer.set_viewport_rect(css.CSSPixelRect.new(0, 0, 800, 600))
	computed := computer.compute_style(dom.AbstractElement.new(element, none))
	return document, css.resolve_computed_values_for_document(computed, document)
}

fn test_absolute_and_percentage_snap_edges_need_no_font_or_container_lookup() {
	mut document, mut computed :=
		snap_context_computed_style('scroll-padding:25% 10% auto 50%;scroll-margin:3px 6px 9px 12px')
	defer { document.finalize() }
	mut used := UsedValues{
		padding_left:   CSSPixels.new(10)
		padding_right:  CSSPixels.new(30)
		padding_top:    CSSPixels.new(20)
		padding_bottom: CSSPixels.new(20)
	}
	used.set_content_width(CSSPixels.new(200))
	used.set_content_height(CSSPixels.new(100))
	computed.cached_length_metrics_ = unsafe { nil }
	padding := compatibility_scroll_snap_edges(computed, used, true)
	margin := compatibility_scroll_snap_edges(computed, used, false)
	assert padding == BoxEdges{
		top:    35
		right:  24
		bottom: 0
		left:   120
	}
	assert margin == BoxEdges{
		top:    3
		right:  6
		bottom: 9
		left:   12
	}
	assert computed.cached_length_metrics_ == unsafe { nil }
	used.set_content_width(CSSPixels.new(400))
	used.set_content_height(CSSPixels.new(200))
	resized := compatibility_scroll_snap_edges(computed, used, true)
	assert resized == BoxEdges{
		top:    60
		right:  44
		bottom: 0
		left:   220
	}
	assert computed.cached_length_metrics_ == unsafe { nil }
}

fn test_relative_and_calculated_snap_edges_keep_their_resolution_context() {
	mut document, mut computed := snap_context_computed_style('font-size:20px')
	defer { document.finalize() }
	// Raw CSSOM values exercise the same typed conversion as a changed style
	// before it has been absolutized by the next complete cascade.
	computed.set_property(.scroll_margin_top, &dom.StyleValue{
		css_text: '2em'
	}, .no, .no)
	computed.set_property(.scroll_margin_right, &dom.StyleValue{
		css_text: '1vw'
	}, .no, .no)
	computed.set_property(.scroll_margin_bottom, &dom.StyleValue{
		css_text: 'calc(1em + 3px)'
	}, .no, .no)
	computed.set_property(.scroll_margin_left, &dom.StyleValue{
		css_text: '7px'
	}, .no, .no)
	computed.cached_length_metrics_ = unsafe { nil }
	edges := compatibility_scroll_snap_edges(computed, &UsedValues{}, false)
	assert edges == BoxEdges{
		top:    40
		right:  8
		bottom: 23
		left:   7
	}
	assert computed.cached_length_metrics_ != unsafe { nil }
}

fn snap_context_box_for_node(box &BlockBox, id i64) ?BlockBox {
	if box.node_id == id { return *box }
	for index in 0 .. box.children.len {
		if found := snap_context_box_for_node(&box.children[index], id) { return found }
	}
	return none
}

fn test_layout_transport_preserves_scroll_padding_and_target_margin() {
	mut document :=
		html.parse_document('<!doctype html><style>html,body{margin:0}#scroller{width:100px;height:100px;overflow:auto;scroll-snap-type:y mandatory;scroll-padding-top:20px}.area{height:100px;scroll-snap-align:start;scroll-margin-top:5px}</style><div id="scroller"><div class="area"></div><div id="second" class="area"></div><div class="area"></div></div>')
	defer { document.finalize() }
	root := layout_document_typed_in_viewport(document, 320, 240)
	scroller := document.get_element_by_id('scroller') or { panic('missing scroller') }
	second := document.get_element_by_id('second') or { panic('missing second area') }
	scroller_box := snap_context_box_for_node(&root, i64(scroller.as_node().unique_id())) or {
		panic('missing scroller transport')
	}
	target_box := snap_context_box_for_node(&root, i64(second.as_node().unique_id())) or {
		panic('missing target transport')
	}
	assert scroller_box.scroll_snap().scroll_padding == BoxEdges{
		top: 20
	}
	assert target_box.scroll_snap().scroll_margin == BoxEdges{
		top: 5
	}
	assert scroller_box.scroll_snap().scroll_snap_type.strictness == .mandatory
	assert target_box.scroll_snap().scroll_snap_align.block_alignment == .start
}
