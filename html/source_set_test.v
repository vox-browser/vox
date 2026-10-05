module html

import css
import dom

fn density_of(source ImageSource) f64 {
	return (source.descriptor as PixelDensityDescriptorValue).value
}

fn test_parse_a_srcset_attribute() {
	set := parse_a_srcset_attribute('small.png 0.5x, normal.png 1x, large.png 2x')
	assert set.sources.len == 3
	assert set.sources[0].url == 'small.png'
	assert density_of(set.sources[0]) == 0.5
	assert set.sources[2].url == 'large.png'
	assert density_of(set.sources[2]) == 2.0

	widths := parse_a_srcset_attribute('small.png 320w, large.png 640w')
	assert widths.sources.len == 2
	assert (widths.sources[0].descriptor as WidthDescriptorValue).value == 320.0

	invalid := parse_a_srcset_attribute('bad.png 1x 2x, good.png 2x')
	assert invalid.sources.len == 1
	assert invalid.sources[0].url == 'good.png'
}

fn test_create_and_select_source_set() {
	set := create_source_set('default.png', 'small.png 0.5x, large.png 2x', 100.0)
	assert set.sources.len == 3
	selected := set.select_an_image_source()
	assert selected.source.url == 'default.png'
	assert selected.pixel_density == 1.0

	mut widths := parse_a_srcset_attribute('small.png 100w, large.png 200w')
	widths.normalize_source_densities_with_source_size(100.0)
	assert density_of(widths.sources[0]) == 1.0
	assert density_of(widths.sources[1]) == 2.0

	document := dom.Document.create(dom.url_about_blank())
	element := document.create_element('img')!
	created := SourceSet.create(element, 'fallback.png', 'wide.png 200w', '100px', none)
	assert created.source_size is css.LengthStyleValue
	assert created.source_size.serialize(.normal) == '100px'
	assert density_of(created.sources[0]) == 2
}

fn test_normalize_source_densities_uses_the_image_document_viewport() {
	mut child_document := dom.Document.create(dom.URL{value: 'about:srcdoc'})
	child_document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	element := child_document.create_element('img')!
	mut source_set := parse_a_srcset_attribute('small.png 100w, large.png 200w')
	source_set.source_size = parse_a_sizes_attribute_style_value(element, '50vw', none)

	source_set.normalize_source_densities(element)
	assert density_of(source_set.sources[0]) == 0.5
	assert density_of(source_set.sources[1]) == 1.0
}

fn test_sizes_attribute_uses_css_parser_media_and_math_algorithms() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_viewport_rect(dom.Rect{0, 0, 800, 600})
	element := document.create_element('img')!

	assert parse_a_sizes_attribute(element, '', none) == 800
	assert parse_a_sizes_attribute(element, '(max-width: 500px) 100px, (min-width: 501px) 50vw', none) == 400
	assert parse_a_sizes_attribute(element, 'calc(50vw - 10px)', none) == 390
	assert parse_a_sizes_attribute(element, 'auto, 25vw', none) == 200
	assert parse_a_sizes_attribute(element, 'url(not-a-size)', none) == 800
	calculated := css.parse_sizes_attribute_style_value(element, 'calc(50vw - 10px)', none)
	assert calculated is css.CalculatedStyleValue
	assert calculated.serialize(.normal) == 'calc(-10px + 50vw)'

	document.set_viewport_rect(dom.Rect{0, 0, 400, 600})
	assert parse_a_sizes_attribute(element, '(max-width: 500px) 100px, (min-width: 501px) 50vw', none) == 100
}
