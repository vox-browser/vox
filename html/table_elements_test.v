module html

import dom

fn table_test_element(node &dom.Node, local_name string) ?&dom.Element {
	if element := node.as_element() {
		if element.local_name() == local_name {
			return element
		}
	}
	for child in node.children_as_vector() {
		if element := table_test_element(child, local_name) {
			return element
		}
	}
	return none
}

fn test_table_caption_sections_and_ordered_rows() {
	document := parse_document('<table><tfoot><tr id="foot"></tr></tfoot><tbody><tr id="body"></tr></tbody><thead><tr id="head"></tr></thead></table>')
	table_dom_element := table_test_element(unsafe { &dom.Node(document) }, 'table') or {
		panic('missing table')
	}
	table := unsafe { &dom.HTMLTableElement(table_dom_element) }
	rows := html_table_element_rows(table)
	assert rows.len == 3
	assert table_row_element(rows[0]).get_attribute_value('id') == 'head'
	assert table_row_element(rows[1]).get_attribute_value('id') == 'body'
	assert table_row_element(rows[2]).get_attribute_value('id') == 'foot'

	caption := create_html_table_element_caption(table) or { panic('${err}') }
	actual_caption := html_table_element_caption(table) or { panic('missing caption') }
	assert actual_caption.as_node().is_same_node(caption.as_node())
	first_child := table_element(table).as_node().first_child() or { panic('missing child') }
	assert first_child.is_same_node(caption.as_node())
	second_caption := create_html_table_element_caption(table) or { panic('${err}') }
	assert second_caption.as_node().is_same_node(caption.as_node())
	delete_html_table_element_caption(table)
	assert html_table_element_caption(table) == none

	body := create_html_table_element_t_body(table) or { panic('${err}') }
	assert html_table_element_t_bodies(table).last().as_node().is_same_node(body.as_node())
}

fn test_table_insert_delete_rows_and_cells() {
	document := parse_document('<table></table>')
	table_dom_element := table_test_element(unsafe { &dom.Node(document) }, 'table') or {
		panic('missing table')
	}
	table := unsafe { &dom.HTMLTableElement(table_dom_element) }
	first := insert_html_table_element_row(table, -1) or { panic('${err}') }
	assert html_table_element_t_bodies(table).len == 1
	second := insert_html_table_element_row(table, 0) or { panic('${err}') }
	assert html_table_element_rows(table) == [second, first]
	assert html_table_row_element_row_index(first) == 1
	assert html_table_row_element_section_row_index(second) == 0

	first_cell := insert_html_table_row_element_cell(first, -1) or { panic('${err}') }
	second_cell := insert_html_table_row_element_cell(first, 0) or { panic('${err}') }
	assert html_table_row_element_cells(first) == [second_cell, first_cell]
	assert html_table_cell_element_cell_index(first_cell) == 1
	delete_html_table_row_element_cell(first, -1) or { panic('${err}') }
	assert html_table_row_element_cells(first).len == 1
	delete_html_table_element_row(table, 0) or { panic('${err}') }
	assert html_table_element_rows(table) == [first]
}

fn test_table_insert_row_uses_the_last_existing_empty_tbody() {
	document := parse_document('<table><tbody id="first"></tbody><tbody id="last"></tbody></table>')
	table_dom_element := table_test_element(unsafe { &dom.Node(document) }, 'table') or {
		panic('missing table')
	}
	table := unsafe { &dom.HTMLTableElement(table_dom_element) }
	bodies := html_table_element_t_bodies(table)
	assert bodies.len == 2

	row := insert_html_table_element_row(table, -1) or { panic('${err}') }
	assert html_table_element_t_bodies(table).len == 2
	parent := table_row_element(row).as_node().parent_node() or { panic('missing row parent') }
	assert parent.is_same_node(table_section_element(bodies.last()).as_node())
}

fn test_table_cell_spans() {
	document := parse_document('<table><tr><td colspan="0" rowspan="0"></td><td colspan="999999999999999999999999" rowspan="70000"></td></tr></table>')
	row_element := table_test_element(unsafe { &dom.Node(document) }, 'tr') or {
		panic('missing row')
	}
	row := unsafe { &dom.HTMLTableRowElement(row_element) }
	cells := html_table_row_element_cells(row)
	assert html_table_cell_element_col_span(cells[0]) == 1
	assert html_table_cell_element_row_span(cells[0]) == 0
	assert html_table_cell_element_col_span(cells[1]) == 1000
	assert html_table_cell_element_row_span(cells[1]) == 65534
	set_html_table_cell_element_col_span(cells[0], 12)
	set_html_table_cell_element_row_span(cells[0], 34)
	assert html_table_cell_element_col_span(cells[0]) == 12
	assert html_table_cell_element_row_span(cells[0]) == 34
}

fn test_table_col_span_border_and_cellpadding() {
	document := parse_document('<table border="7" cellpadding="-2"><colgroup span="0"></colgroup><col span="999999999999999999999999"></table>')
	table_dom_element := table_test_element(unsafe { &dom.Node(document) }, 'table') or {
		panic('missing table')
	}
	table := unsafe { &dom.HTMLTableElement(table_dom_element) }
	assert html_table_element_border(table) == 7
	assert html_table_element_cellpadding(table) or { 99 } == 0
	colgroup_dom_element := table_test_element(unsafe { &dom.Node(document) }, 'colgroup') or {
		panic('missing colgroup')
	}
	colgroup := unsafe { &dom.HTMLTableColElement(colgroup_dom_element) }
	assert html_table_col_element_span(colgroup) == 1
	col_dom_element := table_test_element(unsafe { &dom.Node(document) }, 'col') or {
		panic('missing col')
	}
	col := unsafe { &dom.HTMLTableColElement(col_dom_element) }
	assert html_table_col_element_span(col) == 1000
	set_html_table_col_element_span(col, 12)
	assert html_table_col_element_span(col) == 12
}

fn test_table_cellpadding_attribute_change_caches_and_invalidates_cells() {
	document := parse_document('<table><tr><td></td><th></th></tr></table>')
	table_dom_element := table_test_element(unsafe { &dom.Node(document) }, 'table') or {
		panic('missing table')
	}
	table := unsafe { &dom.HTMLTableElement(table_dom_element) }
	cell_element := table_test_element(unsafe { &dom.Node(document) }, 'td') or {
		panic('missing cell')
	}
	header_element := table_test_element(unsafe { &dom.Node(document) }, 'th') or {
		panic('missing header')
	}
	mut cell_node := unsafe { &dom.Node(cell_element) }
	mut header_node := unsafe { &dom.Node(header_element) }
	cell_node.set_needs_style_update(false)
	header_node.set_needs_style_update(false)

	mut mutable_table := table_dom_element
	mutable_table.set_attribute_value('cellpadding', '-4')
	assert html_table_element_cellpadding(table)? == 0
	assert cell_node.needs_style_update()
	assert header_node.needs_style_update()

	cell_node.set_needs_style_update(false)
	header_node.set_needs_style_update(false)
	mutable_table.remove_attribute('cellpadding')
	assert html_table_element_cellpadding(table)? == 1
	assert cell_node.needs_style_update()
	assert header_node.needs_style_update()
}

fn test_table_cell_default_roles() {
	document := parse_document('<table><thead><tr><th id="column"></th></tr></thead><tbody><tr><th id="row"></th><td id="cell"></td></tr></tbody></table><table role="grid"><tr><td id="gridcell"></td></tr></table>')
	column := unsafe {
		&dom.HTMLTableCellElement(document.get_element_by_id('column') or {
			panic('column')
		})
	}
	row := unsafe {
		&dom.HTMLTableCellElement(document.get_element_by_id('row') or {
			panic('row')
		})
	}
	cell := unsafe {
		&dom.HTMLTableCellElement(document.get_element_by_id('cell') or {
			panic('cell')
		})
	}
	gridcell := unsafe {
		&dom.HTMLTableCellElement(document.get_element_by_id('gridcell') or {
			panic('gridcell')
		})
	}
	assert html_table_cell_element_default_role(column)? == .columnheader
	assert html_table_cell_element_default_role(row)? == .rowheader
	assert html_table_cell_element_default_role(cell)? == .cell
	assert html_table_cell_element_default_role(gridcell)? == .gridcell
}
