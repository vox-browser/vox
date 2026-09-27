module layout

import css
import dom
import encoding.base64
import html
import os

fn test_gif_without_end_of_information_code_retains_intrinsic_size() {
	document := dom.Document.create(dom.url_about_blank())
	size := image_intrinsic_size_for_source(document,
		'data:image/gif;base64,R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7') or {
		panic('GIF without end-of-information code did not load')
	}
	assert size.width?.to_double() == 1
	assert size.height?.to_double() == 1
}

fn test_encoded_image_dimensions_reads_png_and_jpeg_metadata() {
	png := [u8(0x89), `P`, `N`, `G`, 0x0d, 0x0a, 0x1a, 0x0a, 0, 0, 0, 13, `I`, `H`, `D`, `R`, 0,
		0, 2, 128, 0, 0, 1, 224]
	png_size := encoded_image_dimensions(png) or { panic('PNG dimensions') }
	assert png_size.width == 640
	assert png_size.height == 480

	jpeg := [u8(0xff), 0xd8, 0xff, 0xe0, 0, 4, 0, 0, 0xff, 0xc2, 0, 11, 8, 0x01, 0xe0, 0x02, 0x80,
		3, 1, 0x11, 0, 0xff, 0xd9]
	jpeg_size := encoded_image_dimensions(jpeg) or { panic('JPEG dimensions') }
	assert jpeg_size.width == 640
	assert jpeg_size.height == 480
	assert encoded_image_dimensions([u8(0xff), 0xd8, 0xff, 0xc0, 0, 4]) == none
}

fn test_file_image_intrinsic_size_ignores_the_url_query() {
	path := os.join_path(os.temp_dir(), 'vox2-generated-content-${os.getpid()}.png')
	png := base64.decode('iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAIAAAAmkwkpAAAAD0lEQVR4nGNgaGBAIOI4ANA0CAF5jtVRAAAAAElFTkSuQmCC')
	os.write_file(path, png.bytestr()) or { panic(err) }
	defer {
		os.rm(path) or {}
	}
	document := dom.Document.create(dom.URL{value: 'file://${path}'})
	size := image_intrinsic_size_for_source(document, 'file://${path}?content-cache-key') or {
		panic('query-bearing local image did not resolve')
	}
	assert size.width?.to_double() == 4
	assert size.height?.to_double() == 4
}

fn test_image_box_without_decoded_data_has_zero_natural_size() {
	document := dom.Document.create(dom.url_about_blank())
	mut image_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'img')!
	image_element.set_attribute_value('alt', 'fallback text')
	style := css.ComputedProperties.new()
	image_box := ImageBox.new(document, image_element, style)
	assert image_box.natural_size().width?.to_double() == 0
	assert image_box.natural_size().height?.to_double() == 0
}

fn test_video_box_natural_size_tracks_live_media_metadata() {
	document := dom.Document.create(dom.url_about_blank())
	video_element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'video')!
	video := unsafe { &dom.HTMLVideoElement(video_element) }
	mut model := html.html_video_element_model_for_dom_element(video)
	model.set_video_dimensions(640, 360)
	mut media := model.media
	media.set_ready_state(.have_metadata)

	box := VideoBox.new(document, video_element, css.ComputedProperties.new())
	base_box := unsafe { &Box(box) }
	initial := base_box.natural_size()
	assert initial.width?.to_double() == 640
	assert initial.height?.to_double() == 360
	assert initial.aspect_ratio?.numerator().to_double() == 640
	assert initial.aspect_ratio?.denominator().to_double() == 360
	initial_auto_size := base_box.auto_content_box_size()
	assert initial_auto_size.width?.to_double() == 640
	assert initial_auto_size.height?.to_double() == 360

	model.set_video_dimensions(1920, 1080)
	updated := base_box.natural_size()
	assert updated.width?.to_double() == 1920
	assert updated.height?.to_double() == 1080
	updated_auto_size := base_box.auto_content_box_size()
	assert updated_auto_size.width?.to_double() == 1920
	assert updated_auto_size.height?.to_double() == 1080
}

fn test_navigable_container_viewport_uses_svg_natural_size_and_committed_viewport() {
	host_document := dom.Document.create(dom.url_about_blank())
	object_element := host_document.create_element_ns('http://www.w3.org/1999/xhtml', 'object')!
	viewport := NavigableContainerViewport.new(host_document, object_element, css.ComputedProperties.new())

	mut content_document := dom.Document.create(dom.url_about_blank())
	mut svg_root := content_document.create_element_ns('http://www.w3.org/2000/svg', 'svg')!
	svg_root.set_attribute_value('width', '640')
	svg_root.set_attribute_value('height', '360')
	content_document.append_child(svg_root)
	mut mutable_viewport := unsafe { &NavigableContainerViewport(viewport) }
	mutable_viewport.content_document_ = content_document

	base_box := unsafe { &Box(viewport) }
	natural := base_box.natural_size()
	assert natural.width?.to_double() == 640
	assert natural.height?.to_double() == 360
	assert natural.aspect_ratio?.numerator().to_double() == 640
	assert natural.aspect_ratio?.denominator().to_double() == 360

	viewport.did_set_content_size(css.CSSPixelSize.from_values(320, 180))
	assert content_document.viewport_rect().width == 320
	assert content_document.viewport_rect().height == 180
}

fn test_marker_custom_image_counter_style_set_matches_upstream() {
	disc := css.CounterStyle.disc()
	for name in ['square', 'circle', 'disc', 'disclosure-closed', 'disclosure-open'] {
		style := css.CounterStyle.create(name, disc.algorithm(), disc.negative_sign(), disc.prefix(), disc.suffix(), disc.range(), 'decimal', disc.pad())
		assert ListItemMarkerBox.counter_style_is_rendered_with_custom_image(style)
	}
	assert !ListItemMarkerBox.counter_style_is_rendered_with_custom_image(css.CounterStyle.decimal())
	assert !ListItemMarkerBox.counter_style_is_rendered_with_custom_image(none)
}
