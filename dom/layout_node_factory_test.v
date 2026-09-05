module dom

fn test_layout_node_factory_selects_upstream_node_kinds() {
	document := Document.create(url_about_blank())
	element := document.create_element('div')!
	style := &CSSComputedProperties_{}

	assert create_layout_node_for_display_type(document, CSSDisplay_{ is_none_: true }, style,
		element) == none
	assert create_layout_node_for_display_type(document, CSSDisplay_{ is_table_inside_: true },
		style, element)?.layout_node_kind() == .box
	assert create_layout_node_for_display_type(document, CSSDisplay_{ is_list_item_: true }, style,
		element)?.layout_node_kind() == .list_item_box
	assert create_layout_node_for_display_type(document, CSSDisplay_{ is_table_cell_: true }, style,
		element)?.layout_node_kind() == .block_container
	assert create_layout_node_for_display_type(document, CSSDisplay_{ is_inline_outside_: true, is_flow_inside_: true },
		style, element)?.layout_node_kind() == .inline_node
	assert create_layout_node_for_display_type(document, CSSDisplay_{ is_inline_outside_: true, is_flex_inside_: true },
		style, element)?.layout_node_kind() == .box
	assert create_layout_node_for_display_type(document, CSSDisplay_{ is_flow_root_inside_: true },
		style, element)?.layout_node_kind() == .block_container
	assert create_layout_node_for_display_type(document, CSSDisplay_{ is_ruby_inside_: true }, style,
		element)?.layout_node_kind() == .block_container
}
