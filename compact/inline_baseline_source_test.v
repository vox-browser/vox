module main

import html
import layout
import dom

fn test_inline_blocks_export_explicit_first_and_last_baseline_sets() {
	for source in ['first', 'last'] {
		for display in ['inline-block', 'inline-flex', 'inline-grid'] {
			mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{line-height:0;font-size:20px}#reference{display:inline-block;width:20px;height:20px}#inner{display:${display};baseline-source:${source};flex-direction:column;font-size:30px;line-height:0;border:5px solid;padding:10px}#inner span{display:inline-block;width:30px;height:30px}</style><div id="outer"><span id="reference"></span><div id="inner"><div><span></span></div><div><span></span></div></div></div>')
			defer { document.finalize() }
			_ = layout.layout_document_typed_in_viewport(document, 800, 600)
			reference := (document.get_element_by_id('reference') or { panic('reference') }).get_bounding_client_rect()
			inner := (document.get_element_by_id('inner') or { panic('inner') }).get_bounding_client_rect()
			offset := reference.y - inner.y
			expected := if source == 'first' { 25.0 } else { 55.0 }
			assert offset == expected, '${display} ${source}: ${offset}'
		}
	}
}

fn test_explicit_first_baselines_skip_fieldset_legend_and_include_table_caption() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}.target{width:200px;padding:10px;line-height:0;font-size:20px}.inner{border:5px solid;padding:10px;baseline-source:first;font-size:30px}span{display:inline-block;width:1em;height:1em}table{border-spacing:0}tr{vertical-align:baseline}td{padding:0}caption{margin:10px;height:20px}</style><div class="target"><span id="field-reference"></span><fieldset class="inner" style="display:inline-block"><span></span><br><span></span><legend><span></span></legend></fieldset></div><div class="target" id="table-target"><span id="table-reference"></span><table class="inner" style="display:inline-table"><caption></caption><tr><td><span></span><br><span></span></td></tr></table></div>')
 defer { document.finalize() }
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 field := (document.get_element_by_id('field-reference') or { panic('field') }).get_bounding_client_rect()
 assert field.y == 60,'${field.y}'
 table := (document.get_element_by_id('table-reference') or { panic('table') }).get_bounding_client_rect()
 target := (document.get_element_by_id('table-target') or { panic('target') }).get_bounding_client_rect()
 assert table.y-target.y == 75,'${table.y-target.y}'
}

fn test_vertical_inline_blocks_export_the_selected_content_baseline() {
 for mode in ['vertical-lr','vertical-rl'] {
  for source in ['first','last'] {
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{inline-size:200px;padding:10px;border:3px solid;position:relative;line-height:0;font-size:20px;writing-mode:${mode}}#inner{display:inline-block;border:5px solid;padding:10px;baseline-source:${source};font-size:30px}span{display:inline-block;width:1em;height:1em}</style><div id="outer"><span id="reference"></span><div id="inner"><div><span></span></div><div><span></span></div></div></div>')
   defer { document.finalize() }
   _ = layout.layout_document_typed_in_viewport(document,800,600)
   reference := (document.get_element_by_id('reference') or { panic('reference') }).get_bounding_client_rect()
   inner := (document.get_element_by_id('inner') or { panic('inner') }).get_bounding_client_rect()
   expected := if (source=='first') == (mode=='vertical-rl') { 50.0 } else { 20.0 }
   actual := reference.x-inner.x
   assert actual==expected,'${mode} ${source}: ${actual}'
  }
 }
}

fn test_inline_table_border_offset_includes_the_top_caption_origin() {
 mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{width:200px;padding:10px;position:relative;line-height:0;font-size:20px}#table{display:inline-table;border:5px solid;padding:10px;baseline-source:first;font-size:30px;border-spacing:0}tr{vertical-align:baseline}td{padding:0}caption{height:20px;margin:10px}span{display:inline-block;width:1em;height:1em}</style><div id="outer"><span></span><table id="table"><caption></caption><tr><td style="font-size:10px"><span></span><br><span></span></td><td><span></span><br><span></span></td></tr><tr><td><span></span><br><span></span></td><td style="font-size:10px"><span></span><br><span></span></td></tr><caption style="caption-side:bottom"></caption></table></div>')
 defer { document.finalize() }
 _ = layout.layout_document_typed_in_viewport(document,800,600)
 table := document.get_element_by_id('table') or { panic('table') }
 actual := html.html_element_offset_top(unsafe { &dom.HTMLElement(table) })
 assert actual==10,'${actual}'
}

fn test_multicol_baseline_sources_use_balanced_single_line_block_fragments() {
 for mode in ['horizontal-tb','vertical-lr','vertical-rl'] {
  for source in ['first','last'] {
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{position:relative;inline-size:200px;padding:10px;line-height:0;font-size:20px;writing-mode:${mode}}#inner{display:inline-block;columns:2;border:5px solid;padding:10px;baseline-source:${source};font-size:30px}span{display:inline-block;width:1em;height:1em}</style><div id="target"><span id="reference"></span><div id="inner"><div style="font-size:20px"><span></span></div><div style="font-size:20px"><span></span></div><div><span></span></div><div><span></span></div></div></div>')
   defer { document.finalize() }
   document.set_font_rendering_policy(.chromium)
   _ = layout.layout_document_typed_in_viewport(document,800,600)
   reference := (document.get_element_by_id('reference') or { panic('reference') }).get_bounding_client_rect()
   inner := (document.get_element_by_id('inner') or { panic('inner') }).get_bounding_client_rect()
   actual := if mode=='horizontal-tb' { reference.y-inner.y } else { reference.x-inner.x }
   expected := if mode=='horizontal-tb' { if source=='first' { 15.0 } else { 55.0 } } else if mode=='vertical-lr' { if source=='first' { 15.0 } else { 50.0 } } else { if source=='first' { 55.0 } else { 20.0 } }
   assert actual==expected,'${mode} ${source}: ${actual}'
  }
 }
}

fn test_inline_table_transfers_explicit_baseline_source_to_its_anonymous_wrapper() {
 for source in ['first','last'] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}#target{width:200px;padding:10px;position:relative;line-height:0;font-size:20px}#table{display:inline-table;border:5px solid;padding:10px;baseline-source:${source};font-size:30px;border-spacing:0}tr{vertical-align:baseline}td{padding:0}caption{height:20px;margin:10px}span{display:inline-block;width:1em;height:1em}</style><div id="target"><span id="reference"></span><table id="table"><caption></caption><tr><td style="font-size:10px"><span></span><br><span></span></td><td><span></span><br><span></span></td></tr><tr><td><span></span><br><span></span></td><td style="font-size:10px"><span></span><br><span></span></td></tr><caption style="caption-side:bottom"></caption></table></div>')
  defer { document.finalize() }
  _ = layout.layout_document_typed_in_viewport(document,800,600)
  reference := (document.get_element_by_id('reference') or { panic('reference') }).get_bounding_client_rect()
  target := (document.get_element_by_id('target') or { panic('target') }).get_bounding_client_rect()
  expected := if source=='first' { 75.0 } else { 135.0 }
  assert reference.y-target.y==expected,'${source}: ${reference.y-target.y}'
 }
}

fn test_vertical_fieldset_baselines_reserve_the_side_legend_and_skip_its_baseline() {
 mut failures := []string{}
 for policy in [dom.FontRenderingPolicy.libweb,.chromium] {
  for mode in ['vertical-lr','vertical-rl'] {
   for display in ['inline-block','inline-flex'] {
    for source in ['first','last'] {
     mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{inline-size:200px;padding:10px;position:relative;line-height:0;font-size:20px;writing-mode:${mode}}#inner{display:${display};flex-direction:column;border:5px solid;padding:10px;baseline-source:${source};font-size:30px}span{display:inline-block;width:1em;height:1em}</style><div id="outer"><span id="reference"></span><fieldset id="inner"><span></span><br><span></span><legend id="legend"><span></span></legend></fieldset></div>')
     defer { document.finalize() }
     document.set_font_rendering_policy(policy)
     _ = layout.layout_document_typed_in_viewport(document,800,600)
     reference := (document.get_element_by_id('reference') or { panic('reference') }).get_bounding_client_rect()
     inner := (document.get_element_by_id('inner') or { panic('inner') }).get_bounding_client_rect()
     expected := if mode=='vertical-lr' { if source=='first' { 45.0 } else { 75.0 } } else { if source=='first' { 50.0 } else { 20.0 } }
     if reference.x-inner.x!=expected {
      legend := (document.get_element_by_id('legend') or { panic('legend') }).get_bounding_client_rect()
      failures << '${policy} ${mode} ${display} ${source}: ${reference.x-inner.x} expected ${expected}; inner ${inner.width} legend ${legend.width} at ${legend.x-inner.x}'
     }
    }
   }
  }
 }
 assert failures.len==0,failures.join('\n')
}

fn test_vertical_inline_tables_export_row_baselines_with_side_captions() {
 for mode in ['vertical-lr','vertical-rl'] {
  for source in ['first','last'] {
   for nested in [true,false] {
    table := '<table style="border-spacing:0"><caption></caption><tr><td style="font-size:10px"><span></span><br><span></span></td><td><span></span><br><span></span></td></tr><tr><td><span></span><br><span></span></td><td style="font-size:10px"><span></span><br><span></span></td></tr><caption style="caption-side:bottom"></caption></table>'
    content := if nested { '<div id="inner" style="display:inline-block">'+table+'</div>' } else { table.replace('<table style="border-spacing:0">','<table id="inner" style="border-spacing:0;display:inline-table">') }
    mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{inline-size:200px;padding:10px;position:relative;line-height:0;font-size:20px;writing-mode:${mode}}#inner{border:5px solid;padding:10px;baseline-source:${source};font-size:30px}span{display:inline-block;width:1em;height:1em}tr{vertical-align:baseline}td{padding:0}caption{margin:10px;block-size:20px}</style><div id="outer"><span id="reference"></span>${content}</div>')
    defer { document.finalize() }
    _ = layout.layout_document_typed_in_viewport(document,800,600)
    reference := (document.get_element_by_id('reference') or { panic('reference') }).get_bounding_client_rect()
    inner := (document.get_element_by_id('inner') or { panic('inner') }).get_bounding_client_rect()
    expected := if mode=='vertical-lr' { if source=='first' { 60.0 } else { 120.0 } } else { if source=='first' { 150.0 } else { 90.0 } }
    reference_element := document.get_element_by_id('reference') or { panic('reference') }
    inner_element := document.get_element_by_id('inner') or { panic('inner') }
    actual := html.html_element_offset_left(unsafe { &dom.HTMLElement(reference_element) })-html.html_element_offset_left(unsafe { &dom.HTMLElement(inner_element) })
    assert actual==expected,'${mode} ${source} nested=${nested}: ${actual}; rect delta ${reference.x-inner.x}'
   }
  }
 }
}

fn test_vertical_clamped_inline_baselines_fit_the_retained_line_box() {
 for mode in ['vertical-lr','vertical-rl'] {
  for source in ['first','last'] {
   mut document := html.parse_document('<!doctype html><style>body{margin:0}#outer{inline-size:200px;padding:10px;border:3px solid;position:relative;line-height:0;font-size:20px;writing-mode:${mode}}#inner{display:-webkit-inline-box;-webkit-box-orient:vertical;-webkit-line-clamp:3;line-clamp:3 no-ellipsis;overflow:hidden;border:5px solid;padding:10px;baseline-source:${source};font-size:30px}span{display:inline-block;width:1em;height:1em}</style><div id="outer"><span id="reference"></span><div id="inner"><span></span><br><span></span><br><span></span><br><span></span><br></div></div>')
   defer { document.finalize() }
   result := layout.run_document_layout(document,800,600) or { panic("layout") }
   reference := document.get_element_by_id('reference') or { panic('reference') }
   inner := document.get_element_by_id('inner') or { panic('inner') }
   actual_reference := html.html_element_offset_left(unsafe { &dom.HTMLElement(reference) })
   actual_inner := html.html_element_offset_left(unsafe { &dom.HTMLElement(inner) })
   expected := if (source=='first')==(mode=='vertical-rl') { 90.0 } else { 30.0 }
   assert actual_reference==expected && actual_inner==10,'${mode} ${source}: ${actual_reference},${actual_inner}; '+inline_baseline_case_metrics(result.root,result.state,'outer')+'; '+inline_baseline_case_metrics(result.root,result.state,'inner')
  }
 }
}

fn inline_baseline_case_metrics(node &layout.Node,state &layout.LayoutState,id string) string {
 if owner := node.dom_node() {
  if element := owner.as_element() {
   if element.get_attribute_value('id')==id {
    used := state.try_get(node.as_node_with_style() or { return '' }) or { return '' }
    mut lines := []string{}
    for line in used.line_boxes { lines << '${line.bottom_.to_double()}/${line.block_length().to_double()}/${line.baseline().to_double()}' }
    return '${id} ${used.content_width().to_double()}x${used.content_height().to_double()} lines '+lines.join(',')
   }
  }
 }
 for child in node.children() { value := inline_baseline_case_metrics(child,state,id);if value!='' { return value } }
 return ''
}
