module layout

import html
import os

fn test_painted_root_keeps_its_existing_disjoint_and_sticky_picture_policy() {
 for name in ['forum-disjoint-msaa-raster','stackoverflow-sticky-raster-bounds'] {
  mut document := html.parse_document(os.read_file('Tests/Browser/Brave/input/${name}.html') or { panic(err) })
  defer { document.finalize() }
  document.set_font_rendering_policy(.chromium)
  _ = layout_document_typed_in_viewport(document,1024,768)
  commands := display_list_commands(document.record_display_list() or { panic('missing paint') })
  mut plan := ChromiumRasterLayerPlan{}
  update_chromium_raster_layer_plan_for_viewport(document,commands,1,LayoutRect{0,0,1024,768},mut plan)
  assert !plan.has_paint_metadata
 }
}
