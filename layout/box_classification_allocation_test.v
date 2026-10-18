module layout

import css
import dom
import html

$if gcboehm ? {
	fn C.GC_get_total_bytes() usize
}

@[noinline]
fn classify_ordinary_box_without_collections(node &Node) int {
	mut result := 0
	if node.is_scroll_container() { result++ }
	if node.is_absolutely_positioned() { result++ }
	if inherited_user_select_used_value(.none_) == .none_ { result++ }
	return result
}

fn test_repeated_box_classification_does_not_allocate_temporary_enum_collections() {
	mut document := html.parse_document('<!doctype html><div id="box" style="width:50px;height:20px;overflow:hidden;position:absolute">Text</div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 200, 100)
	element := document.get_element_by_id('box')?
	node := unsafe { &Node(element.as_node().unsafe_layout_node()?.real_layout_handle()) }
	assert classify_ordinary_box_without_collections(node) == 3
	mut before := usize(0)
	$if gcboehm ? { before = C.GC_get_total_bytes() }
	mut classified := 0
	for _ in 0 .. 4096 { classified += classify_ordinary_box_without_collections(node) }
	mut allocated := usize(0)
	$if gcboehm ? { allocated = C.GC_get_total_bytes() - before }
	assert classified == 4096 * 3
	assert allocated < 4096, 'classification allocated ${allocated} bytes'
}

fn test_scroll_and_position_classification_keeps_axis_and_viewport_rules() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	styled := NodeWithStyle.new(document, none, css.ComputedProperties.new())
	mut values := unsafe { &css.MutableComputedValues(styled.computed_values()) }
	node := unsafe { &Node(styled) }
	for x in [css.Overflow.visible, .clip, .hidden, .auto_, .scroll] {
		for y in [css.Overflow.visible, .clip, .hidden, .auto_, .scroll] {
			values.set_overflow_x(x)
			values.set_overflow_y(y)
			expected := (x != .visible && x != .clip) || (y != .visible && y != .clip)
			assert node.is_scroll_container() == expected
		}
	}
	for position in [css.Positioning.static_, .relative, .absolute, .fixed, .sticky] {
		values.set_position(position)
		assert node.is_absolutely_positioned() == (position == .absolute || position == .fixed)
	}
	viewport := Viewport.new(document, css.ComputedProperties.new())
	assert unsafe { &Node(viewport) }.is_scroll_container()
}
