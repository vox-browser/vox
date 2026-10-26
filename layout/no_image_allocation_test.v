module layout

import css
import dom
import painting

fn no_image_test_style(declaration string) (&dom.Document, &dom.Element, &css.ComputedProperties, &Node) {
	document := dom.Document.create(dom.URL{ value: 'https://example.test/base/page' })
	mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'div') or {
		panic(err)
	}
	element.set_attribute_value('style', declaration)
	mut computer := css.StyleComputer.new(document)
	computed := computer.compute_style(dom.AbstractElement.new(element, none))
	_ = css.resolve_computed_values_for_document(computed, document)
	node := NodeWithStyle.new(document, element.as_node(), computed)
	return document, element, computed, unsafe { &Node(node) }
}

fn test_absent_background_and_mask_images_need_no_per_box_heap_storage() {
	no_image := css.StyleValue(css.KeywordStyleValue.create(.none_))
	assert computed_image_value_has_no_layers(no_image)
	// A non-coordinating list must retain the old fallback, even when its
	// individual tokens spell `none`.
	assert !computed_image_value_has_no_layers(css.StyleValue(css.StyleValueList.create([no_image], .space, .yes)))
	for declaration in ['', 'background-image:none;mask-image:none',
		'background-image:none,none;mask-image:none,none'] {
		mut document, element, computed, node := no_image_test_style(declaration)
		defer { document.finalize() }
		background := computed.typed_property_value(.background_image) or {
			panic('missing initial background')
		}
		mask := computed.typed_property_value(.mask_image) or { panic('missing initial mask') }
		assert background.as_value_list() != none
		assert computed_image_value_has_no_layers(background)
		assert computed_image_value_has_no_layers(mask)
		context := css.ColorResolutionContext{
			current_color: css.Color{1, 2, 3, 255}
		}
		rect := painting.Rect{7, 9, 120, 60}
		// Exercise the same style repeatedly as it is used by boxes and inline
		// fragments. Warm both accessors before observing aggregate allocation.
		assert computed_background_image_layers(node, element, computed, context).len == 0
		assert css_mask_image_for_box(element, computed, rect, node) == none
		before := gc_heap_usage().total_bytes
		mut image_count := 0
		for _ in 0 .. 2048 {
			image_count += computed_background_image_layers(node, element, computed, context).len
			if css_mask_image_for_box(element, computed, rect, node) != none { image_count++ }
		}
		after := gc_heap_usage().total_bytes
		assert image_count == 0
		$if gcboehm ? {
			assert after == before
		}
	}
}

fn test_none_entries_preserve_nonempty_background_order_and_box_context() {
	mut document, element, computed, node :=
		no_image_test_style('background-image:none,linear-gradient(red,blue),none,url("../back.png");background-size:auto,25px 12px,auto,17px 9px;background-repeat:repeat,no-repeat,repeat,space round;background-origin:border-box,content-box,border-box,padding-box;background-clip:border-box,padding-box,border-box,content-box;background-position:0% 0%,25% 75%,0% 0%,3px 4px;background-attachment:scroll,local,scroll,fixed')
	defer { document.finalize() }
	context := css.ColorResolutionContext{
		current_color: css.Color{11, 22, 33, 255}
	}
	layers := computed_background_image_layers(node, element, computed, context)
	assert layers.len == 2
	assert layers[0].gradient_source != none
	assert layers[0].url == ''
	assert layers[0].size == '25px 12px'
	assert layers[0].origin == 'content-box'
	assert layers[0].clip == 'padding-box'
	assert layers[0].attachment == 'local'
	assert layers[0].gradient_context.current_color == context.current_color
	assert voidptr(layers[0].resolution_context.subject_element or {
		panic('missing gradient subject')
	}) == voidptr(element)
	assert (layers[0].computed_layer or { panic('missing gradient layer') }).repeat_x == .no_repeat
	assert layers[1].gradient_source == none
	assert layers[1].url == 'https://example.test/back.png'
	assert layers[1].size == '17px 9px'
	assert layers[1].origin == 'padding-box'
	assert layers[1].clip == 'content-box'
	assert layers[1].attachment == 'fixed'
	assert layers[1].repeat_x == 'space'
	assert layers[1].repeat_y == 'round'
	assert voidptr(layers[1].resolution_context.subject_element or {
		panic('missing image subject')
	}) == voidptr(element)
}

fn test_none_mask_entries_preserve_image_geometry_and_generated_masks() {
	mut document, element, computed, node :=
		no_image_test_style('mask-image:none,linear-gradient(transparent,transparent),url("../mask.png"),none;image-rendering:pixelated')
	defer { document.finalize() }
	rect := painting.Rect{7, 9, 120, 60}
	mask := css_mask_image_for_box(element, computed, rect, node) or { panic('missing image mask') }
	assert mask.bounding_rect == painting.IntRect{7, 9, 120, 60}
	assert mask.mask_type == .alpha
	assert mask.operations.len == 2
	assert mask.operations[0].kind == .path
	assert mask.operations[1].kind == .image
	assert mask.operations[1].image_url == 'https://example.test/mask.png'
	assert mask.operations[1].image_rect == rect
	assert mask.operations[1].image_rendering == .pixelated
	paintable := mask.operations[1].image_paintable or { panic('missing mask image paintable') }
	assert paintable.object_fit == .fill
	assert paintable.image_rect == rect
	assert voidptr(paintable.resolution_context.subject_element or { panic('missing mask subject') }) == voidptr(element)
	mut gradient_document, gradient_element, gradient_computed, gradient_node :=
		no_image_test_style('mask-image:linear-gradient(transparent,transparent)')
	defer { gradient_document.finalize() }
	transparent := css_mask_image_for_box(gradient_element, gradient_computed, rect, gradient_node) or {
		panic('transparent mask must still hide its contents')
	}
	assert transparent.operations.len == 1
	gradient := transparent.operations[0].fill_linear_gradient or { panic('missing gradient') }
	assert gradient.gradient.color_stops.all(it.color.a == 0)
}
