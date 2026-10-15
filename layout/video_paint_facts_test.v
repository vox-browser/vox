module layout

import dom
import html
import painting

$if gcboehm ? { fn C.GC_gcollect() }

@[heap]
struct VpfProbe {
	red &dom.Bitmap_
	blue &dom.Bitmap_
mut:
	urls []string
}

fn vpf_document() (&dom.Document, &dom.Element, &html.HTMLVideoElementModel, &VpfProbe) {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}video{display:block;width:80px;height:40px}</style><video id="video"></video><video id="unrelated"></video>')
	mut element := document.get_element_by_id('video') or { panic('missing video') }
	mut model := html.html_video_element_model_for_dom_element(unsafe { &dom.HTMLVideoElement(element) })
	// Keep the natural size unchanged when the poster is removed, too.
	model.set_video_dimensions(4, 2)
	probe := &VpfProbe{
		red: &dom.Bitmap_{width: 4, height: 2, pitch: 16, data: [u8(255), 0, 0, 255].repeat(8)}
		blue: &dom.Bitmap_{width: 4, height: 2, pitch: 16, data: [u8(0), 0, 255, 255].repeat(8)}
	}
	model.set_poster_fetch_hook(fn [probe] (url dom.URL) !&dom.Bitmap_ {
		mut observed := unsafe { &VpfProbe(probe) }
		observed.urls << url.serialize()
		if url.serialize().ends_with('/failed.png') { return error('controlled poster failure') }
		return if url.serialize().ends_with('/blue.png') { probe.blue } else { probe.red }
	})
	element.set_attribute_value('poster', 'https://poster.example/red.png')
	_ = layout_document_typed_in_viewport(document, 240, 160)
	return document, element, model, probe
}

fn vpf_command(mut document dom.Document, element &dom.Element) PaintCommand {
	list := document.record_display_list() or { panic('missing display list') }
	commands := display_list_commands(list)
	result := document_layout_result(&document) or { panic('missing layout result') }
	box := result.paint_tree.find_box(i64(element.as_node().unique_id())) or { panic('missing video box') }
	for command in commands {
		if command.kind == 'draw_video' && command.x == box.x && command.y == box.y {
			return command
		}
	}
	panic('missing video command')
}

fn vpf_bitmap(command PaintCommand) &dom.Bitmap_ {
	assert command.video_representation == .poster_frame
	return command.video_bitmap or { panic('missing poster pixels') }
}

fn test_same_size_poster_refreshes_only_its_retained_paint_without_layout() {
	mut document, mut element, mut model, probe := vpf_document()
	defer { document.finalize() }
	initial := vpf_command(mut document, element)
	assert voidptr(vpf_bitmap(initial)) == voidptr(probe.red)
	assert document.element_from_point(4, 4)? == element
	result := document_layout_result(document) or { panic('missing layout') }
	state := voidptr(result.state)
	root := voidptr(result.root)
	children := result.paint_tree.children.data
	order := result.paint_order.data
	hit_order := result.hit_test_order.data
	phases := result.paint_phase_commands.data
	mut target_entry := -1
	mut unrelated_entry := -1
	unrelated := document.get_element_by_id('unrelated') or { panic('missing unrelated video') }
	for index, entry in result.paint_order {
		if entry.box.node_id == i64(element.as_node().unique_id()) { target_entry = index }
		if entry.box.node_id == i64(unrelated.as_node().unique_id()) { unrelated_entry = index }
	}
	assert target_entry >= 0 && unrelated_entry >= 0
	element.set_attribute_value('poster', 'https://poster.example/blue.png')
	assert model.natural_element_size()? == html.VideoDimensions{4, 2}
	assert !element.as_node().unsafe_layout_node()?.needs_layout_update()
	assert !result.paint_phase_entry_valid[target_entry]
	assert result.paint_phase_entry_valid[unrelated_entry]
	assert result.hit_test_display_list_is_valid
	$if gcboehm ? { C.GC_gcollect() }
	updated := vpf_command(mut document, element)
	assert voidptr(vpf_bitmap(updated)) == voidptr(probe.blue)
	assert vpf_bitmap(updated).data[..4] == [u8(0), 0, 255, 255]
	assert vpf_bitmap(initial).data[..4] == [u8(255), 0, 0, 255]
	assert probe.urls == ['https://poster.example/red.png', 'https://poster.example/blue.png']
	assert voidptr(result.state) == state && voidptr(result.root) == root
	assert result.paint_tree.children.data == children
	assert result.paint_order.data == order && result.hit_test_order.data == hit_order
	assert result.paint_phase_commands.data == phases
	assert result.paint_phase_entry_valid.all(it)
	// Re-pushing identical facts does not discard a valid display list.
	cached := document.cached_display_list() or { panic('missing retained list') }
	model.update_natural_dimensions()
	assert voidptr(document.cached_display_list() or { panic('unchanged facts invalidated paint') }) == voidptr(cached)
}

fn test_poster_push_before_first_record_and_clearing_keep_representation_current() {
	mut document, mut element, model, probe := vpf_document()
	defer { document.finalize() }
	assert document.cached_display_list() == none
	element.set_attribute_value('poster', 'https://poster.example/blue.png')
	assert voidptr(vpf_bitmap(vpf_command(mut document, element))) == voidptr(probe.blue)
	for value in ['', 'https://poster.example/red.png', 'https://poster.example/failed.png'] {
		element.set_attribute_value('poster', value)
		command := vpf_command(mut document, element)
		if value.ends_with('/red.png') {
			assert voidptr(vpf_bitmap(command)) == voidptr(probe.red)
		} else {
			assert command.video_representation == .transparent_black
			assert command.video_bitmap == none && command.video_frame_source == none
			paintable := command.video_paintable or { panic('missing video geometry') }
			painted := paintable.paint(command.video_representation, '', none, none,
				painting.new_device_pixel_converter(1) or { panic(err) }) or { panic('missing blank video paint') }
			assert painted.content is painting.FillRect
		}
		assert model.natural_element_size()? == html.VideoDimensions{4, 2}
		assert !element.as_node().unsafe_layout_node()?.needs_layout_update()
	}
	element.set_attribute_value('poster', 'https://poster.example/blue.png')
	before_removal := vpf_command(mut document, element)
	element.remove_attribute('poster')
	removed := vpf_command(mut document, element)
	assert removed.video_representation == .transparent_black && removed.video_bitmap == none
	assert voidptr(vpf_bitmap(before_removal)) == voidptr(probe.blue)
	assert probe.urls.len == 5 // empty and removed attributes never fetch
}

fn test_adopted_video_pushes_facts_to_its_current_document_only() {
	mut original, mut element, model, probe := vpf_document()
	defer { original.finalize() }
	old_command := vpf_command(mut original, element)
	mut destination := html.parse_document('<!doctype html><style>html,body{margin:0}video{display:block;width:80px;height:40px}</style><body></body>')
	defer { destination.finalize() }
	_ = layout_document_typed_in_viewport(destination, 240, 160)
	destination.adopt_node(element.as_node())
	// The old renderer hook is harmless while no new layout box exists.
	element.set_attribute_value('poster', 'https://poster.example/blue.png')
	assert voidptr(vpf_bitmap(old_command)) == voidptr(probe.red)
	mut body := unsafe { &dom.Node(destination.body() or { panic('missing body') }) }
	body.append_child(element.as_node()) or { panic(err) }
	_ = layout_document_typed_in_viewport(destination, 240, 160)
	initial := vpf_command(mut destination, element)
	assert voidptr(vpf_bitmap(initial)) == voidptr(probe.blue)
	result := document_layout_result(destination) or { panic('missing destination layout') }
	state := voidptr(result.state)
	element.set_attribute_value('poster', 'https://poster.example/red.png')
	updated := vpf_command(mut destination, element)
	assert voidptr(vpf_bitmap(updated)) == voidptr(probe.red)
	assert voidptr(vpf_bitmap(initial)) == voidptr(probe.blue)
	assert voidptr(vpf_bitmap(old_command)) == voidptr(probe.red)
	assert voidptr(result.state) == state
	assert voidptr(model.media.document()?) == voidptr(destination)
	assert probe.urls.len == 3
}

fn test_video_metadata_refresh_keeps_old_paint_geometry_immutable() {
	mut document, element, mut model, probe := vpf_document()
	defer { document.finalize() }
	initial := vpf_command(mut document, element)
	old_geometry := initial.video_paintable or { panic('missing initial geometry') }
	assert old_geometry.natural_media_size? == painting.IntSize{4, 2}
	model.set_video_dimensions(8, 4)
	assert model.natural_element_size()? == html.VideoDimensions{4, 2}
	assert !element.as_node().unsafe_layout_node()?.needs_layout_update()
	updated := vpf_command(mut document, element)
	new_geometry := updated.video_paintable or { panic('missing refreshed geometry') }
	assert new_geometry.natural_media_size? == painting.IntSize{8, 4}
	assert old_geometry.natural_media_size? == painting.IntSize{4, 2}
	assert new_geometry.video_rect == old_geometry.video_rect
	assert voidptr(new_geometry) != voidptr(old_geometry)
	assert voidptr(vpf_bitmap(updated)) == voidptr(probe.red)
	assert probe.urls.len == 1
}
