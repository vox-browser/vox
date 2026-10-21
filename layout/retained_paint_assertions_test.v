module layout

import css
import html

fn retained_paint_test_anchor_a(_ voidptr, _ css.AnchorStyleValue) ?css.CSSPixels {
	return none
}

fn retained_paint_test_anchor_b(_ voidptr, _ css.AnchorStyleValue) ?css.CSSPixels {
	return css.CSSPixels.nearest_value_for(1)
}

fn test_retained_paint_comparison_checks_values_and_borrowed_owner_identity() {
	mut first := html.parse_document('<!doctype html><p>owner</p>')
	mut second := html.parse_document('<!doctype html><p>owner</p>')
	defer {
		first.finalize()
		second.finalize()
	}
	left := TextFragment{ text: 'same', background_images: [BackgroundImageLayer{ svg_document: first }] }
	equal := TextFragment{ text: 'same', background_images: [BackgroundImageLayer{ svg_document: first }] }
	other_owner := TextFragment{ text: 'same', background_images: [BackgroundImageLayer{ svg_document: second }] }
	assert retained_paint_payload_equal(left, equal)
	assert !retained_paint_payload_equal(left, other_owner)
	assert !retained_paint_payload_equal(left, TextFragment{ ...left, text: 'changed' })
	assert !retained_paint_payload_equal(TextFragment{ paint_line_top: 3.0 }, TextFragment{})
	assert !retained_paint_payload_equal(TextFragment{ paint_line_top: 3.0 }, TextFragment{ paint_line_top: 4.0 })
	assert !retained_paint_payload_equal([TextFragment{}], []TextFragment{})
	context := css.CalculationResolutionContext{ anchor_resolver: retained_paint_test_anchor_a }
	assert retained_paint_payload_equal(context, context)
	assert !retained_paint_payload_equal(context, css.CalculationResolutionContext{})
	assert !retained_paint_payload_equal(context, css.CalculationResolutionContext{ anchor_resolver: retained_paint_test_anchor_b })
}

fn test_retained_paint_comparison_checks_independent_box_and_command_payloads() {
	mut owner := html.parse_document('<!doctype html><p>borrowed owner</p>')
	defer { owner.finalize() }
	left := BlockBox{ children: [BlockBox{width: 3}],
		svg_solid_color_data: &PaintSVGSolidColorData{fill_serialized: 'red', has_fill: true} }
	equal := BlockBox{ children: [BlockBox{width: 3}],
		svg_solid_color_data: &PaintSVGSolidColorData{fill_serialized: 'red', has_fill: true} }
	assert retained_paint_payload_equal(left, equal)
	assert !retained_paint_payload_equal(left, BlockBox{ ...equal, children: [BlockBox{width: 4}] })
	assert !retained_paint_payload_equal(left, BlockBox{ ...equal,
		svg_solid_color_data: &PaintSVGSolidColorData{fill_serialized: 'blue', has_fill: true} })
	assert !retained_paint_payload_equal(left, BlockBox{ ...equal, svg_solid_color_data: unsafe { nil } })
	command := PaintCommand{ image_data: &PaintImageData{
		image_url: 'icon.svg', background_svg_document: owner } }
	same := PaintCommand{ image_data: &PaintImageData{
		image_url: 'icon.svg', background_svg_document: owner } }
	assert retained_paint_payload_equal(command, same)
	assert !retained_paint_payload_equal(command, PaintCommand{ image_data: &PaintImageData{
		image_url: 'other.svg', background_svg_document: owner } })
}
