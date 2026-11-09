module layout

import css
import html

fn test_interpolated_anchor_insets_keep_both_live_queries() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#cb{position:relative;width:400px;height:250px}#anchor{position:absolute;left:250px;top:50px;width:50px;height:50px;anchor-name:--a}#target{position:absolute;position-anchor:--a;left:anchor(right);width:50px;height:50px}</style><div id="cb"><div id="anchor"></div><div id="target"></div></div>')
	defer { document.finalize() }
	run_document_layout(document,800,600) or { panic('layout') }
	target := document.get_element_by_id('target') or { panic('target') }
	from := css.parse_css_value(css.ParsingParams{},'anchor(right)',.left) or { panic('from') }
	to := css.parse_css_value(css.ParsingParams{},'anchor(left)',.left) or { panic('to') }
	value := css.interpolate_property(target,.left,from,to,0.5,.no) or { panic('interpolation') }
	mut style := css.element_style(target)
	style.set_property_style_value(css.PropertyNameAndID.from_id(.left),value)!
	mut anchor_style := css.element_style(document.get_element_by_id('anchor') or { panic('anchor') })
	for left, expected in {250:275.0,300:325.0} {
		anchor_style.set_property('left','${left}px','')!
		run_document_layout(document,800,600) or { panic('layout') }
		assert target.get_bounding_client_rect().x == expected
	}
}
