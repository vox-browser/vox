module main

import dom
import html
import layout

const table_box_geometry_custom_tags = 'x-table{display:table}x-colgroup{display:table-column-group}x-col{display:table-column}x-tbody{display:table-row-group}x-tr{display:table-row}x-td{display:table-cell}x-caption{display:table-caption}'

fn table_box_geometry_element(document &dom.Document, id string) &dom.Element {
	return document.get_element_by_id(id) or { panic('missing ${id}') }
}

fn table_box_geometry_offset_width(document &dom.Document, id string) int {
	return html.html_element_offset_width(unsafe { &dom.HTMLElement(table_box_geometry_element(document,
		id)) })
}

fn table_box_geometry_offset_height(document &dom.Document, id string) int {
	return html.html_element_offset_height(unsafe { &dom.HTMLElement(table_box_geometry_element(document,
		id)) })
}

fn test_specified_table_height_reaches_empty_rows_after_border_spacing() {
	for sizing in ['border-spacing:10px', 'border:10px solid transparent;box-sizing:border-box'] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}${table_box_geometry_custom_tags}</style>
			<x-table id="table" style="width:120px;height:120px;${sizing}"><x-colgroup id="group"><x-col id="col"></x-col></x-colgroup>
			<x-tbody id="body"><x-tr id="row"><x-td id="cell" style="padding:0"></x-td></x-tr></x-tbody></x-table>')
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		assert table_box_geometry_offset_height(document, 'table') == 120, sizing
		for id in ['cell', 'row', 'body', 'col', 'group'] {
			assert table_box_geometry_offset_width(document, id) == 100, '${sizing} ${id}'
			assert table_box_geometry_offset_height(document, id) == 100, '${sizing} ${id}'
		}
		document.finalize()
	}
	// Rows that already have content receive the specified height less the
	// undistributable spacing; the table keeps its specified height.
	mut document := html.parse_document('<!doctype html><style>body{margin:0}${table_box_geometry_custom_tags}</style>
		<x-table id="table" style="width:120px;height:120px;border-spacing:10px"><x-tr id="row"><x-td style="padding:0"><div style="height:50px"></div></x-td></x-tr>
		<x-tr id="percent" style="height:25%"><x-td style="padding:0"></x-td></x-tr></x-table>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	assert table_box_geometry_offset_height(document, 'table') == 120
	// 25% of the whole 120px grid; the auto row takes the remaining 60px.
	assert table_box_geometry_offset_height(document, 'percent') == 30
	assert table_box_geometry_offset_height(document, 'row') == 60
}

fn test_client_size_rounds_fractional_padding_box_sizes() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}main div{border:1px solid;width:400px}.cell{height:20px}</style>
		<main><div><table width="100%"><tr><td id="half" class="cell" width="0.5%"></td><td>0.5%</td></tr></table>
		<table width="100%"><tr><td id="one" class="cell" width="1%"></td><td>1%</td></tr></table>
		<table width="100%"><tr><td id="five" class="cell" width="5%"></td><td>5%</td></tr></table></div></main>
		<div id="block" style="width:10.6px;height:10.4px"></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	assert table_box_geometry_element(document, 'half').client_width() == 2
	assert table_box_geometry_element(document, 'one').client_width() == 4
	assert table_box_geometry_element(document, 'five').client_width() == 20
	block := table_box_geometry_element(document, 'block')
	assert block.client_width() == 11
	assert block.client_height() == 10
}

fn table_box_geometry_collapse_markup(groups string) string {
	rows := '<x-tr><x-td><span></span></x-td><x-td><span></span></x-td></x-tr>'.repeat(2) +
		'<x-tr><x-td><span></span></x-td><x-td><span style="height:50px"></span></x-td></x-tr>'
	return '<!doctype html><style>body{margin:0}${table_box_geometry_custom_tags}x-table{border:5px solid}x-table span{display:inline-block;vertical-align:top;margin:3px;height:100px;width:100px}</style>
		<x-table id="one"><x-tbody>${rows}</x-tbody></x-table><x-table id="two">${groups}<x-tbody>${rows}</x-tbody></x-table>'
}

fn test_empty_collapsed_column_groups_remove_the_columns_they_span() {
	for groups, width in {
		'<x-colgroup style="visibility:collapse"></x-colgroup>':                                                  116
		'<x-colgroup style="visibility:collapse"></x-colgroup><x-colgroup style="visibility:collapse"></x-colgroup>': 10
		'<x-colgroup span="2" style="visibility:collapse"></x-colgroup>':                                         10
		'<x-colgroup></x-colgroup><x-colgroup style="visibility:collapse"></x-colgroup>':                          116
	} {
		mut document := html.parse_document(table_box_geometry_collapse_markup(groups))
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		assert table_box_geometry_offset_width(document, 'one') == 222, groups
		assert table_box_geometry_offset_width(document, 'two') == width, groups
		assert table_box_geometry_offset_height(document, 'two') == table_box_geometry_offset_height(document,
			'one'), groups
		document.finalize()
	}
	// The column group stands for its columns in the box geometry as well.
	mut document := html.parse_document('<!doctype html><style>body{margin:0}table{border-spacing:0}td{padding:0;width:20px;height:10px}</style>
		<table><colgroup id="group" span="2"></colgroup><tr><td></td><td></td><td></td></tr></table>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	assert table_box_geometry_offset_width(document, 'group') == 40
}

fn test_dynamically_collapsed_column_group_shrinks_the_table() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}table{border:5px solid}table span{display:inline-block;vertical-align:top;margin:3px;height:100px;width:100px}</style>
		<table id="test"><colgroup id="collapse"></colgroup><tbody><tr><td><span></span></td><td><span></span></td></tr>
		<tr><td><span></span></td><td><span></span></td></tr><tr><td><span></span></td><td><span style="height:50px"></span></td></tr></tbody></table>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	assert table_box_geometry_offset_width(document, 'test') == 232
	mut group := table_box_geometry_element(document, 'collapse')
	group.set_attribute_value('style', 'visibility:collapse')
	document.set_needs_full_style_update(true)
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	assert table_box_geometry_offset_height(document, 'test') == 342
	assert table_box_geometry_offset_width(document, 'test') == 122
}

fn test_column_group_width_sizes_its_auto_columns() {
	mut document := html.parse_document('<!doctype html><style>table{height:50px}</style>
		<table id="one" cellspacing="0" cellpadding="0"><colgroup style="width:1px"><col style="width:10px"></colgroup><tr><td style="width:1px"></td></tr></table>
		<table id="two" cellspacing="0" cellpadding="0"><colgroup style="width:10px"><col style="width:1px"></colgroup><tr><td style="width:1px"></td></tr></table>
		<table id="four" cellspacing="0" cellpadding="0"><colgroup style="width:10px"><col></colgroup><tr><td style="width:1px"></td></tr></table>
		<table id="empty" cellspacing="0" cellpadding="0"><colgroup span="2" style="width:15px"></colgroup><tr><td></td><td></td></tr></table>
		<table cellspacing="0" cellpadding="0"><colgroup style="width:51px"><col style="width:20px"><col style="width:auto"></colgroup>
		<tr><td style="width:10px"></td><td id="spanned" style="width:20px"></td></tr></table>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	assert table_box_geometry_offset_width(document, 'one') == 10
	assert table_box_geometry_offset_width(document, 'two') == 1
	assert table_box_geometry_offset_width(document, 'four') == 10
	// A column group without columns gives its width to each column it spans.
	assert table_box_geometry_offset_width(document, 'empty') == 30
	assert table_box_geometry_offset_width(document, 'spanned') == 51
}

fn test_table_element_geometry_describes_the_wrapper_with_its_captions() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}table{border-spacing:0}td{padding:0}caption{height:20px}td div{width:30px;height:10px}</style>
		<table id="top"><caption>C</caption><tr><td><div></div></td></tr></table>
		<table id="bottom" style="border:2px solid;margin:5px"><caption style="caption-side:bottom">C</caption><tr><td><div></div></td></tr></table>
		<table id="none" style="border:2px solid"><tr><td><div></div></td></tr></table>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	top := table_box_geometry_element(document, 'top')
	assert top.get_client_rects().len == 1
	top_rect := top.get_bounding_client_rect()
	assert top_rect.y == 0 && top_rect.width == 30 && top_rect.height == 30, '${top_rect}'
	assert table_box_geometry_offset_width(document, 'top') == 30
	assert table_box_geometry_offset_height(document, 'top') == 30
	bottom_rect := table_box_geometry_element(document, 'bottom').get_bounding_client_rect()
	assert bottom_rect.y == 35 && bottom_rect.width == 34 && bottom_rect.height == 34, '${bottom_rect}'
	assert table_box_geometry_offset_height(document, 'bottom') == 34
	none_rect := table_box_geometry_element(document, 'none').get_bounding_client_rect()
	assert none_rect.width == 34 && none_rect.height == 14, '${none_rect}'
}

fn test_vertical_table_captions_add_their_physical_margins_to_the_block_size() {
	mut document := html.parse_document('<!doctype html><style>
		table{writing-mode:vertical-rl;border-spacing:0;font:10px/1 monospace}td{width:50px;height:30px;padding:0}
		caption{margin:10px 40px}.same caption{writing-mode:vertical-rl}.orthogonal caption{writing-mode:horizontal-tb}.no-margin caption{margin:0}
		</style><table class="same" id="same-margin"><caption>c</caption><tr><td></td></tr></table>
		<table class="same no-margin" id="same-no-margin"><caption>c</caption><tr><td></td></tr></table>
		<table class="orthogonal" id="orthogonal-margin"><caption>c</caption><tr><td></td></tr></table>
		<table class="orthogonal no-margin" id="orthogonal-no-margin"><caption>c</caption><tr><td></td></tr></table>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	for kind in ['same', 'orthogonal'] {
		with_margin := table_box_geometry_element(document, '${kind}-margin').get_bounding_client_rect()
		without := table_box_geometry_element(document, '${kind}-no-margin').get_bounding_client_rect()
		assert with_margin.width - without.width == 80, '${kind}: ${with_margin} ${without}'
		assert with_margin.height == without.height, kind
	}
	// The table's own grid is unaffected by its caption's margins.
	cell := (document.query_selector('#same-margin td') or { panic('cell') }).get_bounding_client_rect()
	assert cell.width == 50 && cell.height == 30, '${cell}'
}

fn test_vertical_table_caption_margins_use_the_wrapper_inline_size() {
	mut document := html.parse_document('<!doctype html><style>${table_box_geometry_custom_tags}
		x-table{width:300px;height:200px;writing-mode:vertical-lr}x-caption{height:50px;width:120px;writing-mode:horizontal-tb}</style>
		<x-table><x-caption id="percent" style="margin-left:20%">caption</x-caption></x-table>
		<x-table><x-caption id="centered" style="margin:auto 0">caption</x-caption></x-table>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document, 800, 600)
	percent := table_box_geometry_element(document, 'percent').as_node().layout_node() or { panic('percent box') }
	assert percent.box_model().margin_left == 40
	centered := table_box_geometry_element(document, 'centered').as_node().layout_node() or { panic('centered box') }
	assert centered.box_model().margin_top == 75
	assert centered.box_model().margin_bottom == 75
}
