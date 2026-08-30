module layout

import css
import dom
import encoding.base64

fn test_gif_decoder_rejects_a_truncated_lzw_stream() {
	truncated := base64.decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7')
	assert !gif_image_data_is_decodable(truncated)

	complete := base64.decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAICRAEAOw==')
	assert gif_image_data_is_decodable(complete)
}

fn test_image_box_recomputes_alt_text_natural_size_after_dom_update() {
	document := dom.Document.create(dom.url_about_blank())
	mut image_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'img')!
	image_element.set_attribute_value('alt', 'iii')
	style := css.ComputedProperties.new()
	mut image_box := ImageBox.new(document, image_element, style)
	assert image_box.renders_as_alt_text()
	old_size := image_box.natural_size()

	image_element.set_attribute_value('alt', 'WWW')
	image_box.dom_node_did_update_alt_text()
	new_size := image_box.natural_size()
	old_width := old_size.width or { panic('alt text has no width') }
	new_width := new_size.width or { panic('alt text has no width') }
	assert new_width.to_double() > old_width.to_double()
	assert new_size.height == old_size.height
}

fn test_marker_custom_image_counter_style_set_matches_upstream() {
	disc := css.CounterStyle.disc()
	for name in ['square', 'circle', 'disc', 'disclosure-closed', 'disclosure-open'] {
		style := css.CounterStyle.create(name, disc.algorithm(), disc.negative_sign(),
			disc.prefix(), disc.suffix(), disc.range(), 'decimal', disc.pad())
		assert ListItemMarkerBox.counter_style_is_rendered_with_custom_image(style)
	}
	assert !ListItemMarkerBox.counter_style_is_rendered_with_custom_image(css.CounterStyle.decimal())
	assert !ListItemMarkerBox.counter_style_is_rendered_with_custom_image(none)
}
