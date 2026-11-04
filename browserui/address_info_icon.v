module browserui

import math
import ui2

// The page-information mark beside the address field. On macOS a "ⓘ" label
// would make AppKit measure a symbol the system font lacks, building CoreText's
// whole fallback cascade at launch, so the native backend draws the mark.
// The custom renderer triangulates vectors and keeps the glyph.
pub fn address_info_mark(id string, frame ui2.Rect, color u32) ui2.Element {
	$if macos && !ui2_custom_rendering ? {
		return address_info_icon(id, frame, color)
	} $else {
		return ui2.label(id, 'ⓘ', frame, ui2.TextStyle{ size: 13, color: color })
	}
}

// The ring and "i" match the glyph at 13pt. They form one filled path: the
// ring's inner contour runs the other way to cut the hole, and zero-width
// bridges reach the stem and dot, so one nonzero-filled contour has all three.
pub fn address_info_icon(id string, frame ui2.Rect, color u32) ui2.Element {
	return ui2.Element{
		...ui2.view(id, frame, ui2.BoxStyle{ transparent: true }, [])
		vector:              ui2.VectorPath{
			points:       address_info_icon_points(8.15, 10.95)
			fill:         color
			stroke_width: 0
		}
		accessibility_label: 'Page information'
	}
}

fn address_info_icon_points(cx f64, cy f64) []ui2.VectorPoint {
	segments := 48
	outer := 6.15
	inner := 5.15
	stem_half := 0.65
	stem_top := cy - 1.83
	stem_bottom := cy + 3.30
	dot_top := cy - 3.83
	dot_bottom := cy - 2.58
	mut points := []ui2.VectorPoint{cap: 2 * (segments + 1) + 16}
	// Outer ring, clockwise on screen from its bottom point.
	for step in 0 .. segments + 1 {
		angle := math.pi / 2 + 2 * math.pi * f64(step) / f64(segments)
		points << ui2.VectorPoint{ x: cx + outer * math.cos(angle), y: cy + outer * math.sin(angle) }
	}
	// Inner ring, counterclockwise, after a bridge from the outer bottom point.
	for step in 0 .. segments + 1 {
		angle := math.pi / 2 - 2 * math.pi * f64(step) / f64(segments)
		points << ui2.VectorPoint{ x: cx + inner * math.cos(angle), y: cy + inner * math.sin(angle) }
	}
	// Clockwise stem and dot, each reached by a bridge that is retraced back.
	for xy in [[cx, stem_bottom], [cx - stem_half, stem_bottom], [cx - stem_half, stem_top],
		[cx + stem_half, stem_top], [cx + stem_half, stem_bottom], [cx, stem_bottom],
		[cx, dot_bottom], [cx - stem_half, dot_bottom], [cx - stem_half, dot_top],
		[cx + stem_half, dot_top], [cx + stem_half, dot_bottom], [cx, dot_bottom],
		[cx, stem_bottom], [cx, cy + inner]] {
		points << ui2.VectorPoint{ x: xy[0], y: xy[1] }
	}
	return points
}
