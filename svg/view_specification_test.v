// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause
module svg

fn test_view_specification_validates_all_attributes_and_duplicates() {
	for input in ['svgView()', 'svgView(viewBox(0 0 10))', 'svgView(viewBox(0 0 10 20);)',
		'svgView(viewBox(0 0 10 20);viewBox(0 0 30 40))', 'svgView(unknown(1))',
		'svgView(preserveAspectRatio(unknown))', 'svgView(transform(rotate()))',
		'svgView(zoomAndPan(other))', 'svgView(viewBox(0 0 10 20))trailing'] {
		assert parse_view_specification(input) == none, input
	}
	value := parse_view_specification('svgView( viewBox (10,20,30,40); preserveAspectRatio(xMaxYMin slice); transform(translate(2 3) scale(4)); zoomAndPan(magnify) )') or { panic('missing specification') }
	assert value.view_box? == ViewBox{10, 20, 30, 40}
	assert (parse_view_specification('svgView(zoomAndPan(disable))') or { panic('valid empty view box') }).view_box == none
}

fn test_view_specification_takes_precedence_over_other_view_boxes() {
	mut viewport := SvgViewport{fit: FitToViewBox{viewbox: ViewBox{0, 0, 100, 100}}}
	mut view := new_element('view')
	view.attributes['viewBox'] = '0 0 80 40'
	viewport.set_active_view(view, ViewBox{1, 2, 60, 20})
	assert viewport.active_viewbox()? == ViewBox{1, 2, 60, 20}
	assert viewport.negotiate_natural_metrics().aspect_ratio? == 3
	viewport.set_active_view_element(view)
	assert viewport.active_viewbox()? == ViewBox{0, 0, 80, 40}
	assert viewport.negotiate_natural_metrics().aspect_ratio? == 2
	viewport.set_active_view(none, none)
	assert viewport.active_viewbox()? == ViewBox{0, 0, 100, 100}
}
