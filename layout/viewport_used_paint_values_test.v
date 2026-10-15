module layout

import css
import dom
import html
import painting

fn viewport_used_paint_node(root &Node, id string) ?&Node {
	if dom_node := root.dom_node() {
		if element := dom_node.as_element() {
			if element.get_attribute_value('id') == id { return root }
		}
	}
	for child in root.children() {
		if node := viewport_used_paint_node(child, id) { return node }
	}
	return none
}

fn viewport_used_paint_fixture() (&dom.Document, &Node, &UsedValues, &css.ComputedValues) {
	document := html.parse_document('<!doctype html><style>html,body{margin:0}#target{display:block;width:80px;height:60px;overflow:auto;resize:inline;writing-mode:horizontal-tb;direction:ltr;scrollbar-width:auto}#child{width:240px;height:240px}</style><div id="target"><div id="child"></div></div>')
	_ = layout_document_typed_in_viewport(document, 320, 180)
	result := document_layout_result(document) or { panic('layout') }
	node := viewport_used_paint_node(result.root, 'target') or { panic('target') }
	styled := node.as_node_with_style() or { panic('style') }
	used := result.state.try_get(styled) or { panic('geometry') }
	return document, node, used, styled.computed_values()
}

fn test_viewport_used_overflow_does_not_create_a_second_body_scrollbar() {
	mut document := html.parse_document('<!doctype html><style>html,body{margin:0}body{height:80px;overflow:auto}#child{height:400px}</style><div id="child"></div>')
	root := layout_document_typed_in_viewport(document, 320, 180)
	body := document.body() or { panic('body') }
	element := unsafe { &dom.Element(body) }
	computed := css.computed_properties_for_element(element) or { panic('computed') }
	assert computed.overflow_x() == .auto_ && computed.overflow_y() == .auto_
	result := document_layout_result(document) or { panic('layout') }
	body_node := viewport_body_box(result.root, element) or { panic('body box') }
	values := body_node.computed_values()
	assert values.overflow_x() == .visible && values.overflow_y() == .visible
	body_box := root.find_box(i64(element.as_node().unique_id())) or { panic('paint body') }
	assert body_box.overlay == none
	assert body_box.overflow_clip == none
	viewport_overlay := root.overlay or { panic('viewport overlay') }
	assert viewport_overlay.can_scroll_vertically
	assert root.paint_commands().filter(it.scrollbar_axis == 'vertical' && it.kind == 'fill_rounded_rect').len == 1
	mut mutable_body := unsafe { &dom.Element(element) }
	mutable_body.set_attribute_value('style', 'color:red')
	document.update_layout(.debugging)
	commands := display_list_commands(document.record_display_list() or { panic('updated paint') })
	assert commands.filter(it.scrollbar_axis == 'vertical' && it.kind == 'fill_rounded_rect').len == 1
	updated := css.computed_properties_for_element(element) or { panic('updated style') }
	assert updated.overflow_x() == .auto_ && updated.overflow_y() == .auto_
	assert values.overflow_x() == .visible && values.overflow_y() == .visible
}

fn test_viewport_used_paint_overlay_reads_box_scrollbar_width_and_overflow() {
	mut document, node, used, source := viewport_used_paint_fixture()
	defer { document.finalize() }
	thin := source.with_viewport_overrides(.auto_, .auto_, .vertical_rl, .rtl, .thin)
	overlay := compatibility_overlay_data(node, thin, used) or { panic('overlay') }
	assert overlay.can_scroll_horizontally && overlay.can_scroll_vertically
	assert overlay.scrollbar_width == .thin
	assert overlay.chrome_mirrored && overlay.has_resizer
	no_bar := thin.with_viewport_overrides(.auto_, .auto_, .vertical_rl, .rtl, .none_)
	assert (compatibility_overlay_data(node, no_bar, used) or { panic('overlay') }).scrollbar_width == .none_
	visible := source.with_viewport_overrides(.visible, .visible, .horizontal_tb, .ltr, .auto_)
	assert compatibility_overlay_data(node, visible, used) == none
	assert !paintable_box_has_resizer(node, visible)
	raw := unsafe { &css.ComputedProperties(thin) }
	assert raw.overflow_x() == .auto_ && raw.overflow_y() == .auto_
	assert raw.scrollbar_width() == .auto_
	assert source.scrollbar_width() == .auto_ && thin.scrollbar_width() == .thin
}

fn test_viewport_used_paint_direction_and_resize_axes_follow_box_writing_mode() {
	mut document, node, _, source := viewport_used_paint_fixture()
	defer { document.finalize() }
	for mode in [css.WritingMode.horizontal_tb, .vertical_rl, .vertical_lr, .sideways_rl] {
		for direction in [css.Direction.ltr, .rtl] {
			values := source.with_viewport_overrides(.auto_, .auto_, mode, direction, .auto_)
			assert paintable_box_physical_resize_axes(node, values) == painting.PhysicalResizeAxes{
				horizontal: mode == .horizontal_tb
				vertical:   mode != .horizontal_tb
			}
			assert paintable_box_is_chrome_mirrored(values) == ((mode == .horizontal_tb && direction == .rtl) || mode in [
				.vertical_rl,
				.sideways_rl,
			])
			assert source.writing_mode() == .horizontal_tb && source.direction() == .ltr
		}
	}
}

fn test_viewport_used_paint_clipping_uses_box_overflow_without_changing_css() {
	mut document, node, used, source := viewport_used_paint_fixture()
	defer { document.finalize() }
	position := css.CSSPixelPoint.new(css.CSSPixels.new(12), css.CSSPixels.new(18))
	visible := source.with_viewport_overrides(.visible, .visible, .horizontal_tb, .ltr, .auto_)
	assert compatibility_overflow_clip(node, visible, used, position, BoxRadii{}) == none
	x_clip := source.with_viewport_overrides(.clip, .visible, .horizontal_tb, .ltr, .auto_)
	clip := compatibility_overflow_clip(node, x_clip, used, position, BoxRadii{}) or { panic('clip') }
	assert clip.rect.x == 12 && clip.rect.width == 80
	assert clip.rect.y == -1_000_000_000.0 && clip.rect.height == 2_000_000_000.0
	y_hidden := source.with_viewport_overrides(.visible, .hidden, .horizontal_tb, .ltr, .auto_)
	second := compatibility_overflow_clip(node, y_hidden, used, position, BoxRadii{}) or { panic('clip') }
	assert second.rect.x == -1_000_000_000.0 && second.rect.width == 2_000_000_000.0
	assert second.rect.y == 18 && second.rect.height == 60
	raw := unsafe { &css.ComputedProperties(y_hidden) }
	assert raw.overflow_x() == .auto_ && raw.overflow_y() == .auto_
	assert source.overflow_x() == .auto_ && source.overflow_y() == .auto_
}
