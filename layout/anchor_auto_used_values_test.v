module layout

import html

fn test_anchor_area_and_center_resolve_auto_insets_and_margins_only_with_a_valid_anchor() {
	for valid in [true,false] {
		for mode in ['area','horizontal','vertical'] {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{position:relative;width:60px;height:60px;padding:15px}#anchor{position:absolute;left:20px;top:20px;width:20px;height:20px;anchor-name:--a}#target{position:absolute;position-anchor:${if valid { "--a" } else { "--missing" }};width:20px;height:20px;${if mode == "area" { "position-area:bottom right" } else if mode == "horizontal" { "justify-self:anchor-center" } else { "align-self:anchor-center" }}}</style><div id="cb"><div id="anchor"></div><div id="target"></div></div>')
			defer { document.finalize() }
			run_document_layout(document,200,200) or { panic('layout') }
			target := document.get_element_by_id('target') or { panic('target') }
			layout_node := target.as_node().layout_node() or { panic('layout node') }
			model := layout_node.box_model()
			if mode != 'vertical' { assert (model.inset_left == 0 && model.inset_right == 0) == valid,'${mode} ${valid}' }
			if mode != 'horizontal' { assert (model.inset_top == 0 && model.inset_bottom == 0) == valid,'${mode} ${valid}' }
		}
	}
}
