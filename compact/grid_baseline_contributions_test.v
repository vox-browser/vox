module main

import html
import layout
import dom

fn test_row_grid_lanes_keep_baseline_offsets_and_include_shims_in_track_sizing() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid-lanes;position:relative;font-size:0;height:0;width:0;align-items:baseline;grid-template-rows:minmax(auto,0px)}#a{padding-top:25px}#b{padding-bottom:25px}#a::before,#b::before{content:"";display:inline-block;width:50px;height:25px;vertical-align:bottom}#b::before{vertical-align:top}#area{position:absolute;inset:0;grid-column:1 / 3;grid-row:1 / 2}</style><div id="grid"><div id="a"></div><div id="b"></div><div id="area"></div></div>')
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		_ = layout.layout_document_typed_in_viewport(document, 800, 600)
		a := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect()
		b := (document.get_element_by_id('b') or { panic('b') }).get_bounding_client_rect()
		area := (document.get_element_by_id('area') or { panic('area') }).get_bounding_client_rect()
		assert b.y - a.y == 50, '${b.y - a.y}'
		assert area.height == 75, '${area.height}'
	}
}

fn test_horizontal_grid_synthesizes_missing_vertical_baselines_from_the_start_border() {
	mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:inline-grid;justify-items:baseline;line-height:0;font-size:0}#a{width:20px;height:20px}#b{writing-mode:vertical-lr;width:30px;height:30px}span{display:inline-block;width:30px;height:30px}</style><div id="grid"><div id="a"></div><div id="b"><span></span></div></div>')
	defer { document.finalize() }
	_ = layout.layout_document_typed_in_viewport(document,800,600)
	a := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect()
	b := (document.get_element_by_id('b') or { panic('b') }).get_bounding_client_rect()
	assert a.x-b.x==15,'${a.x-b.x}'
}

fn test_vertical_grid_lanes_baseline_groups_follow_their_block_direction() {
 for mode in ['vertical-lr','vertical-rl'] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:grid-lanes;position:relative;font-size:0;height:0;width:0;justify-items:baseline;grid-template-columns:minmax(auto,0px)}#a,#b{writing-mode:${mode}}#a{padding-left:25px}#b{padding-right:25px}#a::before,#b::before{content:"";display:inline-block;width:25px;height:50px;vertical-align:top}#b::before{vertical-align:bottom}</style><div id="grid"><div id="a"></div><div id="b"></div></div>')
  defer { document.finalize() }
  _ = layout.layout_document_typed_in_viewport(document,800,600)
  a := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect()
  b := (document.get_element_by_id('b') or { panic('b') }).get_bounding_client_rect()
  expected_a := if mode=='vertical-rl' { -25.0 } else { 0.0 }
  assert a.x==expected_a && b.x-a.x==50,'${mode}: ${a.x},${b.x}'
 }
}

fn test_percentage_sized_grid_items_keep_fallback_alignment_when_their_track_is_intrinsic() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#grid{display:inline-grid;grid-template-columns:100px 100px;align-items:baseline}#a{height:50px}#b{height:200%}</style><div id="grid"><div id="a"></div><div id="b"></div></div>')
 defer { document.finalize() }
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 a := (document.get_element_by_id('a') or { panic('a') }).get_bounding_client_rect()
 b := (document.get_element_by_id('b') or { panic('b') }).get_bounding_client_rect()
 assert a.y==0 && b.y==0 && b.height==100,'${a.y},${b.y},${b.height}'
}
