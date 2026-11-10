// Copyright (c) 2026-present, the Ladybird developers.
// SPDX-License-Identifier: BSD-2-Clause

module css

import dom

fn quirks_color_fixture(mode dom.QuirksMode, position string, zoom int) !(&dom.Document, &dom.Element, &dom.Element, &dom.Element) {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_document_type(.html)
	document.set_quirks_mode(mode)
	document.set_browsing_context(&dom.BrowsingContext{active_document_: document})
	document.set_navigable(&dom.Navigable{active_document_: document, is_top_level_traversable_: true})
	document.populate_with_html_head_and_body()!
	mut root := document.document_element() or { return error('missing document element') }
	root.set_attribute_value('style', 'color:orange;color-scheme:light;zoom:${zoom}')
	native_body := document.body() or { return error('missing body') }
	mut body := unsafe { &dom.Element(native_body) }
	body.set_attribute_value('style', 'color:green')
	mut wrapper := document.create_element('div')!
	wrapper.set_attribute_value('style', 'color:red')
	mut table := document.create_element('table')!
	mut wrapper_node := wrapper.as_node()
	wrapper_node.append_child(table.as_node())!
	row := document.create_element('tr')!
	mut table_node := table.as_node()
	table_node.append_child(row.as_node())!
	mut row_node := row.as_node()
	for name in ['td', 'th'] { row_node.append_child(document.create_element(name)!.as_node())! }
	mut root_node := root.as_node()
	if position == 'before' {
		root_node.pre_insert(wrapper.as_node(), body.as_node())!
	} else if position == 'after' {
		root_node.append_child(wrapper.as_node())!
	} else {
		mut body_node := body.as_node()
		body_node.append_child(wrapper.as_node())!
	}
	_ = css_style_computer_for(document)
	document.update_style()
	return document, body, wrapper, table
}

fn quirks_color_of(element &dom.Element) Color {
	style := computed_properties_for_element(element) or { panic('missing computed style') }
	return resolve_computed_values_for_document(style, element.document()).color()
}

fn test_quirk_inherit_is_only_accepted_as_a_complete_ua_color_value() {
	mut parser := Parser.with_context(ParsingParams{is_ua_style_sheet: .yes}, ' -LIBWEB-QUIRK-INHERIT ')
	value := parser.parse_css_value(.color) or { panic('UA color must accept internal keyword') }
	assert value.to_string() == '-libweb-quirk-inherit'
	for property in [PropertyID.color, .background_color, .border_top_color, .border_color] {
		assert parse_css_value_logic(property, '-libweb-quirk-inherit') == none
	}
	for property in [PropertyID.background_color, .border_top_color, .border_color] {
		mut invalid := Parser.with_context(ParsingParams{is_ua_style_sheet: .yes}, '-libweb-quirk-inherit')
		assert invalid.parse_css_value(property) == none
	}
	mut multiple := Parser.with_context(ParsingParams{is_ua_style_sheet: .yes}, '-libweb-quirk-inherit red')
	assert multiple.parse_css_value(.color) == none
}

fn test_quirks_tables_and_cells_use_the_body_color_before_inside_and_after_the_body() {
	for zoom in [1, 2] {
		for mode in [dom.QuirksMode.no, .limited, .yes] {
			for position in ['before', 'inside', 'after'] {
				mut document, _, _, table := quirks_color_fixture(mode, position, zoom)!
				expected := if mode == .yes { Color{0, 128, 0, 255} } else { Color{255, 0, 0, 255} }
				assert quirks_color_of(table) == expected
				for cell in table.as_node().children[0].children {
					cell_element := cell.as_element() or { panic('expected a table cell element') }
					assert quirks_color_of(cell_element) == expected
				}
				document.finalize()
			}
		}
	}
}

fn test_quirks_table_color_obeys_author_defaulting_and_cascade_rollback() {
	mut document, _, wrapper, mut table := quirks_color_fixture(.yes, 'inside', 1)!
	defer { document.finalize() }
	for value, expected in {
		'blue': Color{0, 0, 255, 255}
		'inherit': Color{255, 0, 0, 255}
		'unset': Color{255, 0, 0, 255}
		'currentcolor': Color{255, 0, 0, 255}
		'var(--missing)': Color{255, 0, 0, 255}
		'initial': Color{0, 0, 0, 255}
		'revert': Color{0, 128, 0, 255}
	} {
		table.set_attribute_value('style', 'color:${value}')
		document.update_style()
		assert quirks_color_of(table) == expected, value
	}
	table.set_attribute_value('style', '--internal:-libweb-quirk-inherit;color:var(--internal)')
	document.update_style()
	assert quirks_color_of(table) == Color{255, 0, 0, 255}
	table.set_attribute_value('style', '')
	add_document_author_style_sheet(document, '@layer lower, higher; @layer lower { .layered { color:purple } } @layer higher { .layered { color:revert-layer } }')
	table.set_attribute_value('class', 'layered')
	document.update_style()
	assert quirks_color_of(table) == Color{128, 0, 128, 255}
	mut fake := document.create_element('div')!
	fake.set_attribute_value('style', 'display:table')
	foreign := document.create_element_ns('urn:test', 'table')!
	mut wrapper_node := wrapper.as_node()
	wrapper_node.append_child(fake.as_node())!
	wrapper_node.append_child(foreign.as_node())!
	document.update_style()
	assert quirks_color_of(fake) == Color{255, 0, 0, 255}
	assert quirks_color_of(foreign) == Color{255, 0, 0, 255}
}

fn test_body_color_changes_restyle_tables_outside_its_subtree_and_do_not_reuse_stale_longhands() {
	for position in ['before', 'inside', 'after'] {
		mut document, mut body, wrapper, mut table := quirks_color_fixture(.yes, position, 1)!
		assert !document.needs_full_style_update()
		body.set_attribute_value('style', 'color:purple')
		document.update_style()
		assert quirks_color_of(table) == Color{128, 0, 128, 255}
		mut second := document.create_element('table')!
		mut wrapper_node := wrapper.as_node()
		wrapper_node.append_child(second.as_node())!
		document.update_style()
		assert quirks_color_of(second) == Color{128, 0, 128, 255}
		body.set_attribute_value('style', 'color:green')
		table.set_attribute_value('style', 'outline-width:1px')
		document.update_style()
		assert quirks_color_of(table) == Color{0, 128, 0, 255}
		assert quirks_color_of(second) == Color{0, 128, 0, 255}
		document.finalize()
	}
}

fn test_quirks_table_uses_the_bodys_used_color_and_initial_color_when_the_body_is_absent() {
	mut document, mut body, _, mut table := quirks_color_fixture(.yes, 'before', 1)!
	defer { document.finalize() }
	body.set_attribute_value('style', 'color:canvastext;color-scheme:dark')
	table.set_attribute_value('style', 'color-scheme:light')
	document.update_style()
	assert quirks_color_of(table) == quirks_color_of(body)
	assert quirks_color_of(table) == SystemColor.canvas_text(.dark)
	mut body_node := body.as_node()
	body_node.remove(false)
	document.update_style()
	assert quirks_color_of(table) == Color{0, 0, 0, 255}
	table.set_attribute_value('style', 'color-scheme:dark')
	document.update_style()
	assert quirks_color_of(table) == SystemColor.canvas_text(.dark)
}

fn test_first_html_body_selection_ignores_framesets_and_updates_when_that_body_is_removed() {
	mut document, body, _, table := quirks_color_fixture(.yes, 'inside', 1)!
	defer { document.finalize() }
	mut root_node := document.document_element()?.as_node()
	mut first := document.create_element('body')!
	first.set_attribute_value('style', 'color:blue')
	root_node.pre_insert(first.as_node(), body.as_node())!
	mut frameset := document.create_element('frameset')!
	frameset.set_attribute_value('style', 'color:red')
	root_node.pre_insert(frameset.as_node(), first.as_node())!
	document.update_style()
	assert quirks_color_of(table) == Color{0, 0, 255, 255}
	mut first_node := first.as_node()
	first_node.remove(false)
	document.update_style()
	assert quirks_color_of(table) == Color{0, 128, 0, 255}
}

fn test_animated_body_color_reaches_an_outside_table_in_the_same_style_update() {
	mut document, mut body, _, table := quirks_color_fixture(.yes, 'before', 1)!
	defer { document.finalize() }
	add_document_author_style_sheet(document, '@keyframes body-color { from { color:red } to { color:blue } }')
	body.set_attribute_value('style', 'animation:body-color 1s linear both')
	document.update_style()
	mut computer := css_style_computer_for(document)
	for sample in [250.0, 750.0, 1000.0] {
		computer.set_animation_time_ms(sample)
		document.update_style()
		assert quirks_color_of(table) == quirks_color_of(body)
		assert computer.ancestor_filter_.buckets.all(it == 0)
	}
}

fn test_inherited_animation_refresh_keeps_ancestor_qualified_author_table_rules() {
	mut document, _, mut wrapper, table := quirks_color_fixture(.yes, 'inside', 1)!
	defer { document.finalize() }
	add_document_author_style_sheet(document, '.scope table { color:purple } @keyframes wrapper-color { from { color:red } to { color:blue } }')
	wrapper.set_attribute_value('class', 'scope')
	wrapper.set_attribute_value('style', 'animation:wrapper-color 1s linear both')
	document.update_style()
	mut computer := css_style_computer_for(document)
	assert quirks_color_of(table) == Color{128, 0, 128, 255}
	for sample in [250.0, 750.0, 1000.0] {
		computer.set_animation_time_ms(sample)
		document.update_style()
		assert quirks_color_of(table) == Color{128, 0, 128, 255}
		assert computer.ancestor_filter_.buckets.all(it == 0)
	}
}

fn test_hidden_root_still_computes_the_body_dependency_before_an_outside_table_query() {
	mut document, mut body, _, table := quirks_color_fixture(.yes, 'before', 1)!
	defer { document.finalize() }
	mut root := document.document_element()?
	root.set_attribute_value('style', 'display:none')
	body.set_attribute_value('style', 'color:blue')
	document.update_style()
	style := up_to_date_computed_properties_for_element(table)
	assert resolve_computed_values_for_document(style, document).color() == Color{0, 0, 255, 255}
}
