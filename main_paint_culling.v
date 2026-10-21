module main

import layout
import math

// Resource and effect groups retain every input leaf, even beyond the canvas.
// Unknown ordinary commands also fall through to their established renderer.
struct PaintCanvasCulling {
mut:
    enabled bool
    depth int
    resource_depth int
    skipped_depth int
}

fn (mut culling PaintCanvasCulling) skip(command &layout.PaintCommand, page_x f64, page_y f64,
    width f64, height f64) bool {
    if !culling.enabled { return false }
    if culling.skipped_depth > 0 {
        if command.kind.starts_with('begin_') { culling.skipped_depth++ }
        else if command.kind.starts_with('end_') { culling.skipped_depth-- }
        return true
    }
    if command.kind.starts_with('end_') {
        if culling.depth > 0 {
            if culling.resource_depth == culling.depth { culling.resource_depth = 0 }
            culling.depth--
        }
        return false
    }
    if command.kind.starts_with('begin_') {
        if culling.resource_depth == 0
            && ((command.kind == 'begin_css_effect_layer'
                && effect_clip_is_outside_canvas(command, page_x, page_y, width, height))
                || (command.kind == 'begin_background_text_clip'
                    && layout.paint_leaf_is_outside_canvas(command, page_x, page_y, width, height))) {
            culling.skipped_depth = 1
            return true
        }
        culling.depth++
        // Opacity and blend scopes do not move ink. Other groups may build
        // masks, filter inputs or source-space resources beyond the viewport.
        if culling.resource_depth == 0 && command.kind != 'begin_css_effect_layer' {
            culling.resource_depth = culling.depth
        }
        return false
    }
    if culling.resource_depth != 0 { return false }
    return layout.paint_leaf_is_outside_canvas(command, page_x, page_y, width, height)
}

fn effect_clip_is_outside_canvas(command &layout.PaintCommand, page_x f64, page_y f64,
    width f64, height f64) bool {
    if !command.has_clip || command.clip_width <= 0 || command.clip_height <= 0
        || width <= 0 || height <= 0 { return false }
    for value in [command.clip_x, command.clip_y, command.clip_width, command.clip_height,
        page_x, page_y, width, height]! {
        if math.is_nan(value) || math.is_inf(value, 0) || math.abs(value) > 1_000_000 {
            return false
        }
    }
    // The renderer applies this clip in canvas coordinates with a two-pixel
    // fringe. Preserve another pixel for native float rounding and coverage.
    return command.clip_x + page_x > width + 3 || command.clip_y + page_y > height + 3
        || command.clip_x + command.clip_width + page_x < -3
        || command.clip_y + command.clip_height + page_y < -3
}
