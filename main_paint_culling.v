module main

import layout

// Resource and effect groups retain every input leaf, even beyond the canvas.
// Unknown ordinary commands also fall through to their established renderer.
struct PaintCanvasCulling {
mut:
    enabled bool
    depth int
}

fn (mut culling PaintCanvasCulling) skip(command &layout.PaintCommand, page_x f64, page_y f64,
    width f64, height f64) bool {
    if !culling.enabled { return false }
    if command.kind.starts_with('end_') {
        if culling.depth > 0 { culling.depth-- }
        return false
    }
    if command.kind.starts_with('begin_') {
        culling.depth++
        return false
    }
    if culling.depth != 0 { return false }
    return layout.paint_leaf_is_outside_canvas(command, page_x, page_y, width, height)
}
