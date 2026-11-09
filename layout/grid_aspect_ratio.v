module layout

import css

fn grid_item_width_from_definite_height(item &Node, item_state &UsedValues, containing_height ?CSSPixels) ?CSSPixels {
 box := item.as_box() or { return none }
 if !box.has_preferred_aspect_ratio() { return none }
 height := item.computed_values().size_value(.height)
 if height.is_auto() || (height.contains_percentage() && containing_height == none) { return none }
 basis := containing_height or { CSSPixels.new(0) }
 resolved := resolve_layout_content_size(item,height,basis,item_state,false) or { return none }
 definite_height := clamp_layout_content_size(item,resolved,basis,item_state,false)
 return intrinsic_content_width_from_aspect_ratio(box,item_state,definite_height)
}
