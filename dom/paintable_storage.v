module dom

// Headers are immutable after publication so by-value paintable snapshots keep
// their previous snap selection when the live box publishes another one.
pub struct PaintableSnapAreas {
pub:
	x []ScrollSnapAreaReference_
	y []ScrollSnapAreaReference_
}

__global empty_paintable_snap_areas = &PaintableSnapAreas{}

pub fn retained_paintable_snap_areas(x []ScrollSnapAreaReference_, y []ScrollSnapAreaReference_) &PaintableSnapAreas {
	if x.len == 0 && y.len == 0 { return unsafe { nil } }
	return &PaintableSnapAreas{x: x, y: y}
}

pub fn (p &PaintableBox) snapped_areas() &PaintableSnapAreas {
	if p.snap_areas_ != unsafe { nil } { return p.snap_areas_ }
	return empty_paintable_snap_areas
}
