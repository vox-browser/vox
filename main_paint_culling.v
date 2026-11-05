module main

import layout
import math
import os

const disable_offscreen_video_culling = os.getenv('VOX_DISABLE_OFFSCREEN_VIDEO_CULLING') != ''
const offscreen_video_culling_diagnostics = os.getenv('VOX_OFFSCREEN_VIDEO_CULLING_DIAGNOSTICS') != ''
const disable_cull_replay_scope_sync = os.getenv('VOX_DISABLE_CULL_REPLAY_SCOPE_SYNC') != ''
const cull_replay_scope_diagnostics = os.getenv('VOX_CULL_REPLAY_SCOPE_DIAGNOSTICS') != ''

// Native video always clips its fitted source to this retained rectangle.
// Compatibility command bounds can differ from it. Keep a rounding fringe
// before applying the same transform and native precision guard as replay.
fn video_is_outside_canvas(command &layout.PaintCommand, page_x f64, page_y f64,
    width f64, height f64) bool {
    if command.outer_shadow || command.blur != 0 { return false }
    paintable := command.video_paintable or { return false }
    rect := paintable.video_rect
    return layout.paint_leaf_is_outside_canvas(&layout.PaintCommand{
        kind: 'fill_rect'
        x: rect.x - 1
        y: rect.y - 1
        width: rect.width + 2
        height: rect.height + 2
        transform: command.transform
    }, page_x, page_y, width, height)
}

// Resource and effect groups retain every input leaf, even beyond the canvas.
// Unknown ordinary commands also fall through to their established renderer.
struct PaintCanvasCulling {
mut:
    enabled bool
    depth int
    resource_depth int
    skipped_depth int
}

@[inline]
fn (mut culling PaintCanvasCulling) advance_scope(kind string) {
    if !culling.enabled { return }
    if culling.skipped_depth > 0 {
        if kind.starts_with('begin_') { culling.skipped_depth++ }
        else if kind.starts_with('end_') { culling.skipped_depth-- }
        return
    }
    if kind.starts_with('end_') {
        if culling.depth > 0 {
            if culling.resource_depth == culling.depth { culling.resource_depth = 0 }
            culling.depth--
        }
    } else if kind.starts_with('begin_') {
        culling.depth++
        if culling.resource_depth == 0 && kind != 'begin_css_effect_layer' {
            culling.resource_depth = culling.depth
        }
    }
}

// Native grouped handlers replay their closing commands too. Account for
// those boundaries when the outer loop skips their already-painted range;
// otherwise an ended mask can keep all later leaves in resource-input mode.
fn (mut culling PaintCanvasCulling) replayed_command(command &layout.PaintCommand) {
    if disable_cull_replay_scope_sync || !culling.enabled { return }
    before := culling.resource_depth
    culling.advance_scope(command.kind)
    if cull_replay_scope_diagnostics && (command.kind.starts_with('begin_') || command.kind.starts_with('end_')) {
        eprintln('VOX_CULL_REPLAY_BOUNDARY kind=${command.kind} resource_before=${before} resource_after=${culling.resource_depth} depth=${culling.depth}')
    }
}

fn (mut culling PaintCanvasCulling) skip(command &layout.PaintCommand, page_x f64, page_y f64,
    width f64, height f64) bool {
    if !culling.enabled { return false }
    if culling.skipped_depth > 0 {
        culling.advance_scope(command.kind)
        return true
    }
    if command.kind.starts_with('end_') {
        culling.advance_scope(command.kind)
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
        // Opacity and blend scopes do not move ink. Other groups may build
        // masks, filter inputs or source-space resources beyond the viewport.
        culling.advance_scope(command.kind)
        return false
    }
    if culling.resource_depth != 0 { return false }
    if command.kind == 'draw_video' && !disable_offscreen_video_culling
        && video_is_outside_canvas(command, page_x, page_y, width, height) {
        if offscreen_video_culling_diagnostics {
            eprintln('VOX_OFFSCREEN_VIDEO_CULL skipped=1')
        }
        return true
    }
    return layout.paint_leaf_is_outside_canvas(command, page_x, page_y, width, height)
}

fn effect_clip_is_outside_canvas(command &layout.PaintCommand, page_x f64, page_y f64,
    width f64, height f64) bool {
    if !command.has_clip || width <= 0 || height <= 0 { return false }
    for value in [command.clip_x, command.clip_y, command.clip_width, command.clip_height,
        page_x, page_y, width, height]! {
        if math.is_nan(value) || math.is_inf(value, 0) || math.abs(value) > 1_000_000 {
            return false
        }
    }
    // A bounded effect can become empty after intersecting an ancestor clip.
    // Its native transparency surface is clipped to that empty rectangle too.
    if command.clip_width == 0 || command.clip_height == 0 { return true }
    if command.clip_width < 0 || command.clip_height < 0 { return false }
    // The renderer applies this clip in canvas coordinates with a two-pixel
    // fringe. Preserve another pixel for native float rounding and coverage.
    return command.clip_x + page_x > width + 3 || command.clip_y + page_y > height + 3
        || command.clip_x + command.clip_width + page_x < -3
        || command.clip_y + command.clip_height + page_y < -3
}
