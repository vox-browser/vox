module layout

import css
import dom

fn border_radius_test_values(document &dom.Document, style string) &css.ComputedValues {
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	element.set_attribute_value('style', style)
	mut computer := css.StyleComputer.new(document)
	computed := computer.compute_style(dom.AbstractElement.new(element, none))
	return css.resolve_computed_values_for_document(computed, document)
}

fn test_percentage_paint_radii_keep_float_precision_only_in_chromium() {
	for chromium in [false, true] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		if chromium { document.set_font_rendering_policy(.chromium) }
		values := border_radius_test_values(document, 'border-radius:20%')
		radius := paintable_box_border_radii_data(values, CSSPixels.from_raw(819), CSSPixels.from_raw(716)).top_left
		if chromium {
			assert radius == CornerRadius{f64(f32(12.796875) * f32(20) / f32(100)), f64(f32(11.1875) * f32(20) / f32(100))}
		} else {
			assert radius == CornerRadius{2.546875, 2.234375}
		}
	}
}

fn test_fractional_and_calculated_paint_radii_avoid_layout_unit_rounding() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	for style in ['border-radius:2.559375px / 2.2375px', 'border-radius:calc(20% + 0px)'] {
		values := border_radius_test_values(document, style)
		radius := paintable_box_border_radii_data(values, CSSPixels.from_raw(819), CSSPixels.from_raw(716)).top_left
		assert radius == CornerRadius{f64(f32(2.559375)), f64(f32(2.2375))}
	}
}

fn test_chromium_radii_overlap_uses_one_float_scale_for_all_corners() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_font_rendering_policy(.chromium)
	values := border_radius_test_values(document, 'border-top-left-radius:50px; border-top-right-radius:70px; border-bottom-left-radius:10px 5px')
	radii := paintable_box_border_radii_data(values, CSSPixels.new(100), CSSPixels.new(100))
	factor := f32(100) / f32(120)
	assert radii.top_left == CornerRadius{f64(f32(50) * factor), f64(f32(50) * factor)}
	assert radii.top_right == CornerRadius{f64(f32(70) * factor), f64(f32(70) * factor)}
	assert radii.bottom_left == CornerRadius{f64(f32(10) * factor), f64(f32(5) * factor)}
	assert radii.bottom_right == CornerRadius{}
}
