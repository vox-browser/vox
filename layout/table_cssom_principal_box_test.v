module layout

import css
import dom
import html

// Ladybird 283f73dbe6164f05dc0d49b68fa128b880319d4b.
fn test_table_resolved_insets_and_margins_use_the_wrapper_geometry() {
	mut document := html.parse_document('<!doctype html><style>
		body{margin:0}.cb{position:relative;width:400px;height:100px}
		.table{display:table;width:50px;height:20px}.cell{display:table-cell}
	</style>
	<div class="cb"><div id="absolute" class="table" style="position:absolute;top:10%;left:5%"><div class="cell"></div></div></div>
	<div class="cb"><div id="relative" class="table" style="position:relative;top:10%;left:5%"><div class="cell"></div></div></div>
	<div class="cb"><div id="margins" class="table" style="margin:7px 11px 13px 17px"><div class="cell"></div></div></div>
	<div class="cb"><div id="auto" class="table" style="margin:0 auto"><div class="cell"></div></div></div>
	<div class="cb"><div id="inline" class="table" style="display:inline-table;position:relative;top:3px;margin-left:5px"><div class="cell"></div></div></div>')
	defer { document.finalize() }
	_ = layout_document_typed_in_viewport(document, 800, 600)
	for id in ['absolute', 'relative'] {
		element := document.get_element_by_id(id) or { panic(id) }
		style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(element, none))
		assert style.get_property_value('top') == '10px', '${id}: top=${style.get_property_value('top')}'
		assert style.get_property_value('left') == '20px', '${id}: left=${style.get_property_value('left')}'
		assert style.get_property_value('width') == '50px'
		assert style.get_property_value('height') == '20px'
	}
	margins := document.get_element_by_id('margins') or { panic('margins') }
	margins_style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(margins, none))
	assert margins_style.get_property_value('margin-top') == '7px'
	assert margins_style.get_property_value('margin-right') == '11px'
	assert margins_style.get_property_value('margin-bottom') == '13px'
	assert margins_style.get_property_value('margin-left') == '17px'
	auto_table := document.get_element_by_id('auto') or { panic('auto') }
	auto_style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(auto_table, none))
	assert auto_style.get_property_value('margin-left') == '175px'
	assert auto_style.get_property_value('margin-right') == '175px'
	inline_table := document.get_element_by_id('inline') or { panic('inline') }
	inline_style := css.CSSStyleProperties.create_resolved_style(dom.AbstractElement.new(inline_table, none))
	assert inline_style.get_property_value('top') == '3px'
	assert inline_style.get_property_value('margin-left') == '5px'
}
