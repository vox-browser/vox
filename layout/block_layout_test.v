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
