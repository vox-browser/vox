module layout

import dom

struct CompletedBackgroundResource {
	document        ?&dom.Document
	resource        ?&StaticSVGBackgroundResource
	intrinsic_width f64
	intrinsic_height f64
}

// A completed CSS background changes decoded paint input, not style or layout.
// The caller has already excluded resources used by replaced/generated images.
// Keep the general renderer refresh for every pending style, geometry or paint
// update; its snapshots may contain changes beyond these resource bytes.
pub fn refresh_document_background_resources(document &dom.Document, changed map[string]bool) bool {
	if changed.len == 0 || !document.layout_is_up_to_date()
		|| document.needs_style_update_after_layout() { return false }
	mut result := document_layout_result(document) or { return false }
	if result.needs_repaint || result.paint_tree.layout_handle == unsafe { nil }
		|| document.cached_display_list() == none { return false }
	node := document.as_node()
	root := document.document_element() or { return false }
	if node.needs_style_update() || node.child_needs_style_update()
		|| node.entire_subtree_needs_style_update() || document.element_needs_style_update(root) {
		return false
	}
	if !background_resource_refresh_supported(result.paint_tree) { return false }
	mut resources := map[string]CompletedBackgroundResource{}
	mut changed_boxes := []&BlockBox{}
	if !refresh_background_resources_in_box(mut result.paint_tree, result.root, changed, mut resources, mut changed_boxes) {
		return false
	}
	// Box addresses and every visual/hit-test property remain unchanged. Discard
	// command buckets so recording observes the new image owners, while keeping
	// the retained stacking, hit-test and scroll plans attached to those boxes.
	for box in changed_boxes { viewport_invalidate_box_paint_cache(mut result, box) }
	result.drop_display_list_scene()
	result.needs_repaint = true
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_needs_repaint_with_invalidation(.paint_commands)
	return true
}

fn background_resource_refresh_supported(box &BlockBox) bool {
	// Keep resource-bearing masks/filters and nested documents on the general
	// refresh path; this slice updates CSS background layers only.
	if box.svg_mask != none || box.svg_clip != none || box.filter.has_svg_filters()
		|| box.backdrop_filter.has_svg_filters() || box.nested_viewport_document != none {
		return false
	}
	// Borrow each child: passing a loop copy's address would heap-allocate it.
	for i in 0 .. box.children.len {
		if !background_resource_refresh_supported(&box.children[i]) { return false }
	}
	return true
}

fn refreshed_background_resource_layers(layers []BackgroundImageLayer, root &Node,
	changed map[string]bool, mut resources map[string]CompletedBackgroundResource) ([]BackgroundImageLayer, bool) {
	mut updated := []BackgroundImageLayer{}
	mut did_update := false
	for index, layer in layers {
		if layer.url.all_before('#') !in changed { continue }
		if !did_update {
			updated = layers.clone()
			did_update = true
		}
		key := layer.color_scheme.str() + '\n' + layer.url
		resource := resources[key] or {
			image := svg_background_image_for_source_in_viewport(root, layer.url, layer.color_scheme)
			width, height := image.intrinsic_dimensions()
			value := CompletedBackgroundResource{
				document: image.document
				resource: image.resource
				intrinsic_width: width
				intrinsic_height: height
			}
			resources[key] = value
			value
		}
		updated[index] = BackgroundImageLayer{
			...layer
			svg_document: resource.document
			static_svg_resource: resource.resource
			intrinsic_width: resource.intrinsic_width
			intrinsic_height: resource.intrinsic_height
		}
	}
	if did_update { return updated, true }
	return layers, false
}

fn refresh_background_resources_in_box(mut box BlockBox, root &Node,
	changed map[string]bool, mut resources map[string]CompletedBackgroundResource, mut changed_boxes []&BlockBox) bool {
	layers, own_update := refreshed_background_resource_layers(box.background_images, root, changed, mut resources)
	if own_update { box.background_images = layers }
	mut did_update := own_update
	for line_index := 0; line_index < box.lines.len; line_index++ {
		for fragment_index := 0; fragment_index < box.lines[line_index].fragments.len; fragment_index++ {
			fragment := box.lines[line_index].fragments[fragment_index]
			fragment_layers, fragment_update := refreshed_background_resource_layers(fragment.background_images,
				root, changed, mut resources)
			if fragment_update {
				box.lines[line_index].fragments[fragment_index] = TextFragment{
					...fragment
					background_images: fragment_layers
				}
				did_update = true
			}
		}
	}
	if did_update { changed_boxes << unsafe { &box } }
	for mut child in box.children {
		if refresh_background_resources_in_box(mut child, root, changed, mut resources, mut changed_boxes) { did_update = true }
	}
	return did_update
}
