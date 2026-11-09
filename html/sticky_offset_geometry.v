module html

import dom

fn html_offset_sticky_displacement(document &dom.Document, node &dom.LayoutNode) dom.CSSPixelPoint_ {
 mut mutable_document := unsafe { &dom.Document(document) }
 mutable_document.update_paint_and_hit_testing_properties_if_needed()
 viewport := document.unsafe_paintable() or { return dom.CSSPixelPoint_{} }
 return viewport.sticky_position_offset(node.real_layout_handle())
}
