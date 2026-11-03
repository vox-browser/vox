module main

import layout
import math

fn decoration_bounds_fixture() []layout.PaintCommand {
    fill := layout.PaintCommand{kind: 'fill_rect', x: 100.25, y: 50.5,
        width: 217, height: 52, radius: 3, color: 'rgb(70 127 194)', opacity: 1}
    return [fill, layout.PaintCommand{...fill, kind: 'paint_uniform_border', stroke_width: 2}]
}

fn test_small_decoration_checkpoint_covers_ink_without_viewport_rows() {
    commands := decoration_bounds_fixture()
    bounds := chromium_rounded_pair_recording_bounds(commands, 0, 2, 112, 1708, 953) or { panic('missing decoration bounds') }
    assert bounds.x <= 99.25 && bounds.x + bounds.width >= 318.25
    assert bounds.y <= 161.5 && bounds.y + bounds.height >= 215.5
    // Two Retina copies previously reserved over 52 MB for this small pair.
    // The conservative bounded reservation is under one percent of that area.
    assert bounds.width * bounds.height * 100 < 1708 * 953
}

fn test_decoration_checkpoint_uses_transformed_viewport_geometry() {
    mut commands := decoration_bounds_fixture()
    for i in 0 .. commands.len {
        commands[i].y += 1000
        commands[i].transform = [f64(1), 0, 0, 1, 0, -1000]!
    }
    scrolled := chromium_rounded_pair_recording_bounds(commands, 0, 2, 112, 1708, 953) or { panic('missing decoration bounds') }
    assert scrolled.y > 150 && scrolled.y < 170
    for i in 0 .. commands.len {
        commands[i].transform = [f64(0), 1, -1, 0, 1200, 0]!
    }
    rotated := chromium_rounded_pair_recording_bounds(commands, 0, 2, 112, 1708, 953) or { panic('missing decoration bounds') }
    assert rotated.x <= 95.5 && rotated.x + rotated.width >= 151.5
    assert rotated.y <= 211.25 && rotated.y + rotated.height >= 430.25
    clipped := chromium_rounded_pair_recording_bounds(decoration_bounds_fixture(), 0, 2, 112, 200, 80) or { panic('missing clipped decoration bounds') }
    assert clipped.x >= 2 && clipped.x + clipped.width <= 198
    assert clipped.y >= 114 && clipped.y + clipped.height <= 190
}

fn test_unknown_decoration_ink_preserves_viewport_fallback() {
    base := decoration_bounds_fixture()
    for command in [
        layout.PaintCommand{...base[1], kind: 'begin_css_effect_layer'},
        layout.PaintCommand{...base[1], blur: 4},
        layout.PaintCommand{...base[1], x: 1e12},
        layout.PaintCommand{...base[1], stroke_width: math.nan()},
    ] {
        assert chromium_rounded_pair_recording_bounds([base[0], command], 0, 2, 112, 1708, 953) == none
    }
    assert chromium_rounded_pair_recording_bounds(base, -1, 2, 112, 1708, 953) == none
    assert chromium_rounded_pair_recording_bounds(base, 0, 3, 112, 1708, 953) == none
    assert chromium_rounded_pair_recording_bounds(base, 0, 2, 112, 4, 953) == none
}
