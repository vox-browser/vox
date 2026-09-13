module dom

fn test_svg_image_color_scheme_overrides_the_host_page_preference() {
	mut document := Document.create(URL{ value: 'https://example.test/image.svg' })
	document.set_needs_full_style_update(false)
	assert document.svg_image_color_scheme() == none
	assert document.preferred_color_scheme() == 'auto'

	document.set_svg_image_color_scheme('dark')
	assert document.svg_image_color_scheme()? == 'dark'
	assert document.preferred_color_scheme() == 'dark'
	assert document.needs_full_style_update()

	document.set_needs_full_style_update(false)
	document.set_svg_image_color_scheme('dark')
	assert !document.needs_full_style_update()
}
