module dom

pub fn (viewport &ViewportPaintable) sticky_position_offset(layout_handle voidptr) CSSPixelPoint_ {
 if viewport.target == unsafe { nil } || viewport.sticky_position_offset_callback == unsafe { nil } { return CSSPixelPoint_{} }
 return viewport.sticky_position_offset_callback(viewport.target,layout_handle)
}
