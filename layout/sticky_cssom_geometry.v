module layout

import dom

// CSSOM offset geometry includes sticky positioning, while excluding scroll
// translations and CSS transforms. Sum only sticky frames in the live chain.
fn viewport_sticky_position_offset(target voidptr, layout_handle voidptr) dom.CSSPixelPoint_ {
 if layout_handle == unsafe { nil } { return dom.CSSPixelPoint_{} }
 mut result := viewport_layout_result(target)
 if result.paint_projection_incomplete && result.retained_box_for_layout(layout_handle) == none { restore_complete_paint_projection(mut result) }
 box := result.retained_box_for_layout(layout_handle) or { return dom.CSSPixelPoint_{} }
 mut index := box.own_scroll_frame_index
 if index == 0 { index = paintable_box_nearest_scroll_frame_index(box,result.boxes_by_layout_cache) }
 mut offset := dom.CSSPixelPoint_{}
 for index > 0 && index < result.scroll_state.frames.len {
  frame := result.scroll_state.frame_at(index)
  if frame.is_sticky() { own := frame.own_offset();offset.x_ += own.x;offset.y_ += own.y }
  index = frame.parent_index()
 }
 return offset
}

fn compatibility_box_establishes_scroll_frame(box &BlockBox) bool {
 if box.is_viewport_scroller || box.has_scrollable_overflow { return true }
 if box.layout_handle == unsafe { nil } { return false }
 return unsafe { &Node(box.layout_handle) }.is_scroll_container()
}
