module main

import css
import dom
import html
import layout

fn test_zero_font_size_keeps_normal_line_height_and_top_aligned_baselines_zero() {
	for policy in [dom.FontRenderingPolicy.libweb,.chromium] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{font-size:0;line-height:0}#top,#reference{display:inline-block}#top{font-size:0;line-height:normal}#top>span{display:inline-block;vertical-align:top;width:10px;height:25px}#reference{width:10px;height:20px}</style><div id="outer"><div id="top"><span></span></div><span id="reference"></span></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		_ = layout.layout_document_typed_in_viewport(document,800,600)
		top := document.get_element_by_id('top') or { panic('top') }
		computed := css.up_to_date_computed_properties_for_element(top)
		assert computed.line_height().raw_value()==0
		a := top.get_bounding_client_rect()
		b := (document.get_element_by_id('reference') or { panic('reference') }).get_bounding_client_rect()
		assert a.y-b.y==20,'${policy}: ${a.y-b.y}'
	}
}
