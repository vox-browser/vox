module layout

import css
import dom
import math

#include "gradient_resolver_lifetime_test.h"

$if gcboehm ? {
	fn C.vox_gradient_owner_watch(index u32, owner voidptr)
	fn C.vox_gradient_owner_collect(depth u32)
	fn C.vox_gradient_owner_worker(work fn ())
	fn C.vox_gradient_owner_alive() u32
}

__global gradient_lifetime_retained LinearGradient

fn gradient_lifetime_value(text string) css.StyleValue {
	mut parser := css.Parser.with_context(css.ParsingParams{}, text)
	value := parser.parse_css_value(.background_image) or { panic('invalid ${text}') }
	if list := value.as_value_list() {
		assert list.size() == 1
		return list.value_at(0, false)
	}
	return value
}

fn gradient_lifetime_context() css.LengthResolutionContext {
	mut context := css.LengthResolutionContext.default()
	context.font_metrics.font_size = css.CSSPixels.nearest_value_for(20)
	context.root_font_metrics.font_size = css.CSSPixels.nearest_value_for(16)
	context.viewport_rect = css.CSSPixelRect.new(0, 0, 1000, 500)
	return context
}

fn test_gradient_borrowed_resolver_keeps_relative_calc_and_zero_length_positions() {
	context := gradient_lifetime_context()
	color := css.ColorResolutionContext{}
	linear := resolve_background_gradient(gradient_lifetime_value('linear-gradient(90deg, red 2em, blue calc(50% + 10px))'),
		200, 100, context, color) or { panic('missing linear gradient') }
	assert math.abs(linear.stops[0].offset - 0.2) < 1e-12
	assert math.abs(linear.stops[1].offset - 0.55) < 1e-12
	assert math.abs(linear.x1) < 1e-12
	assert math.abs(linear.x2 - 1) < 1e-12
	vertical := resolve_background_gradient(gradient_lifetime_value('linear-gradient(180deg, red 1rem, blue 10vh)'),
		200, 100, context, color) or { panic('missing vertical gradient') }
	assert math.abs(vertical.stops[0].offset - 0.16) < 1e-12
	assert math.abs(vertical.stops[1].offset - 0.5) < 1e-12
	zero := resolve_background_gradient(gradient_lifetime_value('linear-gradient(90deg, red 2em, blue 90%)'),
		0, 0, context, color) or { panic('missing zero-sized gradient') }
	assert zero.stops.len == 2
	assert zero.stops[0].offset == 0 && zero.stops[1].offset == 0
}

fn test_gradient_borrowed_resolver_preserves_radial_geometry_and_conic_angles() {
	context := gradient_lifetime_context()
	color := css.ColorResolutionContext{}
	radial := resolve_background_gradient(gradient_lifetime_value('radial-gradient(ellipse 100px 50px at 25% 75%, red 1em, blue 75%)'),
		200, 100, context, color) or { panic('missing radial gradient') }
	assert radial.kind == 'radial'
	assert radial.center_x == 0.25 && radial.center_y == 0.75
	assert radial.radius_x == 0.5 && radial.radius_y == 0.5
	assert math.abs(radial.stops[0].offset - 0.2) < 1e-12
	assert math.abs(radial.stops[1].offset - 0.75) < 1e-12
	conic := resolve_background_gradient(gradient_lifetime_value('conic-gradient(from 45deg at 20% 30%, red 90deg, blue 75%)'),
		200, 100, context, color) or { panic('missing conic gradient') }
	assert conic.kind == 'conic'
	assert conic.center_x == 0.2 && conic.center_y == 0.3
	assert conic.start_degrees == 45
	assert conic.stops[0].offset == 0.25 && conic.stops[1].offset == 0.75
}

fn test_gradient_borrowed_resolver_keeps_physical_direction_with_rtl_subjects() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	mut subject := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	subject.set_attribute_value('dir', 'rtl')
	mut context := gradient_lifetime_context()
	context.subject_element = subject
	left := resolve_background_gradient(gradient_lifetime_value('linear-gradient(to left, red 2em, blue 90%)'),
		200, 100, context, css.ColorResolutionContext{}) or { panic('missing RTL subject gradient') }
	assert math.abs(left.x1 - 1) < 1e-12
	assert math.abs(left.x2) < 1e-12
	assert left.stops[0].offset == 0.2 && left.stops[1].offset == 0.9
}

fn test_gradient_borrowed_resolver_preserves_hints_double_stops_and_repeating_lengths() {
	gradient := gradient_lifetime_value('repeating-linear-gradient(90deg, red 10px 20px, 25px, blue 30px)').as_linear_gradient() or {
		panic('missing repeating gradient')
	}
	resolver := TypedGradientPositionResolver{
		resolution_context: gradient_lifetime_context()
		reference_length:   100
	}
	data := resolve_color_stop_positions(gradient.color_stop_list_, css.ColorResolutionContext{},
		gradient.is_repeating(), resolver)
	assert data.repeating
	assert data.list.len == 3
	assert math.abs((data.repeat_length or { panic('missing repeat length') }) - 0.2) < 1e-12
	assert data.list[0].position == 0.1
	assert data.list[1].position == 0.2
	assert data.list[2].position == 0.3
	assert math.abs((data.list[2].transition_hint or { panic('missing transition hint') }) - 0.5) < 1e-12
	assert data.list[0].color == data.list[1].color
	assert data.list[0].color != data.list[2].color
}

@[noinline]
fn gradient_lifetime_resolve_owned(text string) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_scripting_enabled_by_embedder(false)
	element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or { panic(err) }
	mut context := gradient_lifetime_context()
	context.subject_element = element
	gradient_lifetime_retained = resolve_background_gradient(gradient_lifetime_value(text),
		200, 100, context, css.ColorResolutionContext{}) or { panic('missing owned gradient') }
	$if gcboehm ? {
		C.vox_gradient_owner_watch(0, voidptr(document))
		C.vox_gradient_owner_watch(1, voidptr(element))
	}
	document.finalize()
}

fn gradient_lifetime_resolve_linear() {
	gradient_lifetime_resolve_owned('linear-gradient(90deg, red 2em, blue 90%)')
}

fn gradient_lifetime_resolve_radial() {
	gradient_lifetime_resolve_owned('radial-gradient(ellipse 100px 50px, red 1em, blue 75%)')
}

fn test_linear_gradient_resolution_releases_document_and_subject_element() {
	$if gcboehm ? {
		C.vox_gradient_owner_worker(gradient_lifetime_resolve_linear)
		C.vox_gradient_owner_collect(8)
		C.vox_gradient_owner_collect(8)
		mask := C.vox_gradient_owner_alive()
		println('linear_gradient_owner_mask=${mask}')
		assert mask == 0
	} $else {
		gradient_lifetime_resolve_linear()
	}
	retained := gradient_lifetime_retained
	assert retained.stops.len == 2
	assert retained.stops[0].offset == 0.2 && retained.stops[1].offset == 0.9
}

fn test_radial_gradient_resolution_releases_document_and_subject_element() {
	$if gcboehm ? {
		C.vox_gradient_owner_worker(gradient_lifetime_resolve_radial)
		C.vox_gradient_owner_collect(8)
		C.vox_gradient_owner_collect(8)
		mask := C.vox_gradient_owner_alive()
		println('radial_gradient_owner_mask=${mask}')
		assert mask == 0
	} $else {
		gradient_lifetime_resolve_radial()
	}
	retained := gradient_lifetime_retained
	assert retained.radial && retained.stops.len == 2
	assert retained.stops[0].offset == 0.2 && retained.stops[1].offset == 0.75
}
