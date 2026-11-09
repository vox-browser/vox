module main

import browserjs
import html
import layout

fn test_native_listbox_keeps_intrinsic_axes_without_containment_overrides() {
 for rows in [2,4,10] {
  mut document := html.parse_document('<!doctype html><style>body{margin:0}select{padding:0}.test{display:grid-lanes;contain:size;border:1px solid}#width{contain-intrinsic-size:55px none}#height{contain-intrinsic-size:none 66px}</style><select id="reference" multiple size="${rows}"></select><select id="width" class="test" multiple size="${rows}"></select><select id="height" class="test" multiple size="${rows}"></select>')
  defer { document.finalize() }
  document.set_font_rendering_policy(.chromium)
  _ = layout.layout_document_typed_in_viewport(document,800,600)
  reference := (document.get_element_by_id('reference') or { panic('reference') }).get_bounding_client_rect()
  width := (document.get_element_by_id('width') or { panic('width') }).get_bounding_client_rect()
  height := (document.get_element_by_id('height') or { panic('height') }).get_bounding_client_rect()
  assert width.width==57 && width.height==reference.height,'${rows}: ${width.width}x${width.height}, reference ${reference.height}'
  assert height.height==68 && height.width==reference.width,'${rows}: ${height.width}x${height.height}, reference ${reference.width}'
 }
}

fn test_select_size_reflects_unsigned_values_and_mutations_to_its_content_attribute() {
 mut document := html.parse_document('<!doctype html><select id="select" multiple size="2"></select>')
 mut runtime := browserjs.Runtime.create()
 defer { runtime.close();document.finalize() }
 mut messages := []string{}
 run_document_javascript(document,'about:blank',[r'
 const select=document.getElementById("select");
 if(select.size!==2)throw Error("initial size");
 for(const [input,expected] of [[4,4],[10,10],[0,0],[-1,0],[3.9,3],[4294967298,2],[Infinity,0]]){
  select.size=input;
  if(select.size!==expected||select.getAttribute("size")!==String(expected))throw Error("size write "+input);
 }
 select.setAttribute("size","  +12px");if(select.size!==12)throw Error("attribute parsing");
 select.removeAttribute("size");if(select.size!==0)throw Error("missing size");
 '],runtime,mut messages)
 assert messages==[]string{},messages.str()
}
