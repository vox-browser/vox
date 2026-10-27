module layout

import css
import dom

fn empty_shadow_context_style(declaration string) (&dom.Document, &css.ComputedValues) {
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

fn assert_empty_shadows_need_no_context_storage(node &Node, computed &css.ComputedValues) {
	assert computed.box_shadow().len == 0
	assert computed.text_shadow().len == 0
	assert computed_box_shadows(node, computed).len == 0
	assert computed_text_shadows(computed).len == 0
	before := gc_heap_usage().total_bytes
	mut count := 0
	for _ in 0 .. 2048 {
		count += computed_box_shadows(node, computed).len
		count += computed_text_shadows(computed).len
	}
	after := gc_heap_usage().total_bytes
	assert count == 0
	$if gcboehm ? {
		assert after == before
	}
}

fn test_empty_cached_shadows_skip_context_storage_with_and_without_a_subject() {
	without_subject := &css.ComputedProperties{}
	assert without_subject.subject_element_ == none
	mut empty_document := dom.Document.create(dom.url_about_blank())
	defer { empty_document.finalize() }
	assert_empty_shadows_need_no_context_storage(Node.new(empty_document, none), without_subject)
	for declaration in ['', 'box-shadow:none;text-shadow:none'] {
		mut document, computed := empty_shadow_context_style(declaration)
		defer { document.finalize() }
		assert computed.subject_element_ != none
		assert_empty_shadows_need_no_context_storage(Node.new(document, none), computed)
	}
}

fn test_nonempty_box_and_text_shadows_keep_units_colors_order_and_context() {
	mut document, computed :=
		empty_shadow_context_style('width:50%;font-size:20px;color:rgb(11 22 33);box-shadow:currentColor 1em 2vw 3px 4px inset, blue -2px 3px;text-shadow:red 0.5em 1vw 2px,currentColor -3px 4px')
	defer { document.finalize() }
	context := css.LengthResolutionContext.for_computed_properties(computed)
	assert context.subject_element != none
	assert context.query_container_cache != none
	expected_box := computed_shadow_transport(computed.box_shadow(), context)
	expected_text := computed_shadow_transport(computed.text_shadow(), context)
	node := Node.new(document, none)
	box := computed_box_shadows(node, computed)
	text := computed_text_shadows(computed)
	assert box == expected_box
	assert text == expected_text
	assert box.len == 2
	assert box[0].offset_x == 20
	assert box[0].offset_y == 16
	assert box[0].blur == 3
	assert box[0].spread == 4
	assert box[0].inset
	assert box[0].color == css.Color{11, 22, 33, 255}
	assert box[1].offset_x == -2
	assert !box[1].inset
	assert text.len == 2
	assert text[0].offset_x == 10
	assert text[0].offset_y == 8
	assert text[0].blur == 2
	assert text[1].offset_x == -3
	assert text[1].color == css.Color{11, 22, 33, 255}
	gc_collect()
	assert box == computed_box_shadows(node, computed)
	assert text == computed_text_shadows(computed)
}
