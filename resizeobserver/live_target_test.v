module resizeobserver

import dom

fn test_live_target_reads_latest_committed_box_in_css_coordinates() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_layout_coordinate_scale(2)
	document.set_display_device_pixel_ratio(3)
	element := document.create_element('div')!
	mut node := element.as_node()
	mut box := &dom.LayoutNode{
		has_geometry_:   true
		display_:        dom.CSSDisplay_{ is_block_outside_: true, is_flow_inside_: true }
		content_width_:  200
		content_height_: 100
	}
	box.set_box_model(dom.LayoutBoxModel{ padding_left: 12, padding_right: 12, padding_top: 8, padding_bottom: 8, border_left: 4, border_right: 4, border_top: 4, border_bottom: 4 })
	node.set_layout_node(box)
	target := ResizeTarget.for_element(element)
	entry := ResizeObserverEntry.create_and_populate(target)
	assert entry.content_rect().width() == 100
	assert entry.content_rect().height() == 50
	assert entry.content_rect().x() == 6
	assert entry.content_rect().y() == 4
	assert entry.border_box_size()[0].inline_size() == 116
	assert entry.device_pixel_content_box_size()[0].inline_size() == 348
	box.content_width_ = 240
	assert ResizeObserverSize.compute_box_size(target, .content_box).inline_size() == 120
	assert entry.content_rect().width() == 100
	box.has_geometry_ = false
	assert ResizeObserverSize.compute_box_size(target, .border_box).inline_size() == 0
	box.has_geometry_ = true
	box.display_ = dom.CSSDisplay_{ is_inline_outside_: true, is_flow_inside_: true }
	assert ResizeObserverSize.compute_box_size(target, .content_box).inline_size() == 0
	box.is_atomic_inline_ = true
	assert ResizeObserverSize.compute_box_size(target, .content_box).inline_size() == 120
}
