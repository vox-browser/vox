module layout

fn has_definite_inline_size(node &Node,values &UsedValues) bool {
 return if node.computed_values().writing_mode() == .horizontal_tb { values.has_definite_width() } else { values.has_definite_height() }
}
