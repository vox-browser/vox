module layout

import dom
import html
import painting

// Resolve posters from the current paint owner, rather than treating decoded
// live frames or a retained snapshot from an old document as image resources.
pub fn video_poster_resource_url(document &dom.Document, command &PaintCommand) ?string {
	if command.kind != 'draw_video' || command.video_representation != .poster_frame
		|| command.video_frame_source != none { return none }
	result := document_layout_result(document) or { return none }
	if command.paint_box_index < 0 || command.paint_box_index >= result.paint_order.len { return none }
	box := result.paint_order[command.paint_box_index].box
	paintable := command.video_paintable or { return none }
	current := box.media().video_paintable or { return none }
	if voidptr(paintable) != voidptr(current)
		|| video_paint_bitmap_identity(command.video_bitmap) != video_paint_bitmap_identity(box.media().video_bitmap) {
		return none
	}
	node := dom.Node.from_unique_id(dom.UniqueNodeID(box.node_id)) or { return none }
	if voidptr(node.document()) != voidptr(document) { return none }
	element := node.as_element() or { return none }
	if !element.is_html_element() || element.local_name() != 'video' { return none }
	poster := element.get_attribute_ns(none, 'poster') or { return none }
	if poster == '' { return none }
	return (document.encoding_parse_url(poster) or { return none }).serialize()
}

// Painting::push_video_paint_facts(). Resolve the current document and layout
// owner on every push; an adopted or unboxed video must not update an old tree.
fn push_video_paint_facts(element &dom.HTMLVideoElement) {
	node := unsafe { &dom.Node(element) }
	layout_node := node.unsafe_layout_node() or { return }
	handle := layout_node.real_layout_handle()
	if handle == unsafe { nil } { return }
	document := node.document()
	mut result := document_layout_result(document) or { return }
	mut box := video_paint_box_for_layout_handle(mut result.paint_tree, handle) or { return }
	model := html.html_video_element_model_for_dom_element(element)
	representation := match model.current_representation() {
		.video_frame { painting.VideoRepresentation.video_frame }
		.first_video_frame { painting.VideoRepresentation.first_video_frame }
		.poster_frame { painting.VideoRepresentation.poster_frame }
		.transparent_black { painting.VideoRepresentation.transparent_black }
	}
	bitmap := if representation == .poster_frame { model.poster_frame() } else { ?&dom.Bitmap_(none) }
	mut source := ?&painting.VideoFrameSource(none)
	if representation in [.video_frame, .first_video_frame] {
		mut media := model.media
		source = media.ensure_video_frame_source()
	}
	paintable := box.media().video_paintable or { return }
	natural_size := if dimensions := model.natural_media_size() {
		?painting.IntSize(painting.IntSize{int(dimensions.width), int(dimensions.height)})
	} else { ?painting.IntSize(none) }
	if box.media().video_representation == representation
		&& video_paint_bitmap_identity(box.media().video_bitmap) == video_paint_bitmap_identity(bitmap)
		&& video_paint_source_identity(box.media().video_frame_source) == video_paint_source_identity(source)
		&& paintable.natural_media_size == natural_size {
		return
	}
	// Existing boxes and display lists retain their previous immutable snapshot.
	next_paintable := if paintable.natural_media_size != natural_size {
		&painting.VideoPaintable{
			...paintable
			natural_media_size: natural_size
		}
	} else { paintable }
	box.media_data = retained_block_box_media(BlockBoxMediaData{
		...*box.media()
		video_representation: representation
		video_bitmap: bitmap
		video_frame_source: source
		video_paintable: next_paintable
	})
	viewport_invalidate_box_paint_cache(mut result, box)
	mut mutable_document := unsafe { &dom.Document(document) }
	mutable_document.set_needs_repaint_with_invalidation(.paint_commands)
}

fn video_paint_box_for_layout_handle(mut box BlockBox, handle voidptr) ?&BlockBox {
	if box.layout_handle == handle && box.media().video_paintable != none {
		return unsafe { &box }
	}
	for mut child in box.children {
		if found := video_paint_box_for_layout_handle(mut child, handle) { return found }
	}
	return none
}

fn video_paint_bitmap_identity(bitmap ?&dom.Bitmap_) voidptr {
	if value := bitmap { return voidptr(value) }
	return unsafe { nil }
}

fn video_paint_source_identity(source ?&painting.VideoFrameSource) voidptr {
	if value := source { return voidptr(value) }
	return unsafe { nil }
}
