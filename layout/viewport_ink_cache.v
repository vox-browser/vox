module layout

import dom
import math
import os
import platform

const disable_viewport_ink_cache = os.getenv('VOX_DISABLE_VIEWPORT_INK_CACHE') != ''
const disable_viewport_ink_bounds = os.getenv('VOX_DISABLE_VIEWPORT_INK_BOUNDS') != ''

struct ViewportCachedEntryInk {
	first int
	count int
	bounded bool
	// Union of the components when every one is a finite positive-area rect.
	// An affine image of a component lies inside the image of the union, so a
	// union beyond one viewport edge proves each component is beyond it. Long
	// documents reject almost every entry with this one test.
	has_bounds bool
	bounds     LayoutRect
	prepaint   bool
}

// Private recording workspace. Rectangles contain no paint-tree or glyph roots.
// Keep each component separately: ink above and below a viewport must not turn
// into one visible union across the empty space between them.
struct ViewportEntryInkCache {
mut:
	valid bool
	revision u64
	order voidptr
	entries []ViewportCachedEntryInk
	rects []LayoutRect
	// Network background images of every entry, including culled ones.
	background_urls []string
}

fn (mut cache ViewportEntryInkCache) invalidate() {
	cache.valid = false
	cache.order = unsafe { nil }
	cache.entries.clear()
	cache.rects.clear()
	cache.background_urls.clear()
}

fn refresh_viewport_entry_ink_cache(mut result DocumentLayoutResult) {
	revision := result.document.paint_content_revision()
	if result.record_scratch.viewport_ink_cache.valid
		&& result.record_scratch.viewport_ink_cache.revision == revision
		&& result.record_scratch.viewport_ink_cache.order == result.paint_order.data
		&& result.record_scratch.viewport_ink_cache.entries.len == result.paint_order.len { return }
	// Like the recording plan, this storage outlives the temporary visibility
	// arena and is transferred to the replacement result on relayout.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	mut cache := &result.record_scratch.viewport_ink_cache
	cache.invalidate()
	mut seen_urls := map[string]bool{}
	for entry in result.paint_order {
		collect_viewport_entry_background_urls(entry.box, mut seen_urls, mut cache.background_urls)
		first := cache.rects.len
		bounded := append_viewport_entry_ink(entry.box, mut cache.rects)
		bounds, has_bounds := viewport_ink_component_bounds(cache.rects, first)
		cache.entries << ViewportCachedEntryInk{
			first:      first
			count:      cache.rects.len - first
			bounded:    bounded
			has_bounds: bounded && has_bounds
			bounds:     bounds
			prepaint:   viewport_entry_paints_images(entry.box)
		}
	}
	cache.revision = revision
	cache.order = result.paint_order.data
	cache.valid = true
}

// Mirrors the shell's prefetch of recorded backgrounds: network URLs that are
// not SVG documents, from boxes with a non-empty painting area.
fn collect_viewport_entry_background_urls(box &BlockBox, mut seen map[string]bool, mut urls []string) {
	layers := box.decorations().background_images
	if layers.len == 0 { return }
	border := box.border_box()
	if !(border.width > 0 && border.height > 0) { return }
	for layer in layers {
		if layer.svg_document != none || layer.static_svg_resource != none { continue }
		if !layer.url.starts_with('http://') && !layer.url.starts_with('https://') { continue }
		if layer.url in seen { continue }
		owned := layer.url.clone()
		seen[owned] = true
		urls << owned
	}
}

// Network background images of every painted entry, also those the latest
// viewport recording left out, while its entry cache is current. Empty when
// no viewport recording has validated the cache for this paint revision.
pub fn document_background_image_urls(document &dom.Document) []string {
	result := document_layout_result(document) or { return []string{} }
	cache := &result.record_scratch.viewport_ink_cache
	if !cache.valid || cache.revision != document.paint_content_revision()
		|| cache.order != result.paint_order.data || cache.entries.len != result.paint_order.len {
		return []string{}
	}
	return cache.background_urls
}

fn viewport_ink_component_bounds(rects []LayoutRect, first int) (LayoutRect, bool) {
	if first >= rects.len { return LayoutRect{}, false }
	mut left := f64(0)
	mut top := f64(0)
	mut right := f64(0)
	mut bottom := f64(0)
	for index in first .. rects.len {
		rect := rects[index]
		// Degenerate or non-finite components never prove an entry outside;
		// keep their exact per-component result.
		if !(rect.width > 0 && rect.height > 0) || math.is_nan(rect.x) || math.is_nan(rect.y)
			|| math.is_inf(rect.x, 0) || math.is_inf(rect.y, 0) || math.is_inf(rect.width, 0)
			|| math.is_inf(rect.height, 0) {
			return LayoutRect{}, false
		}
		if index == first {
			left, top = rect.x, rect.y
			right, bottom = rect.x + rect.width, rect.y + rect.height
			continue
		}
		left = math.min(left, rect.x)
		top = math.min(top, rect.y)
		right = math.max(right, rect.x + rect.width)
		bottom = math.max(bottom, rect.y + rect.height)
	}
	return LayoutRect{left, top, right - left, bottom - top}, true
}

fn append_viewport_entry_ink(box &BlockBox, mut rects []LayoutRect) bool {
	if !viewport_entry_has_bounded_ink(box) { return false }
	border := box.border_box()
	outset := math.max(f64(0), box.decorations().outline_width + math.abs(box.decorations().outline_offset)) + 2
	rects << LayoutRect{border.x - outset, border.y - outset,
		border.width + outset * 2, border.height + outset * 2}
	if box.canvas().paints_canvas_background {
		rects << LayoutRect{box.canvas().canvas_x, box.canvas().canvas_y,
			box.canvas().canvas_width, box.canvas().canvas_height}
	}
	for line in box.lines {
		for index in 0 .. line.fragments.len {
			if !append_viewport_fragment_ink(unsafe { &line.fragments[index] }, mut rects) { return false }
		}
		for index in 0 .. line.box_decorations.len {
			if !append_viewport_fragment_ink(unsafe { &line.box_decorations[index] }, mut rects) { return false }
		}
	}
	return true
}

fn append_viewport_fragment_ink(fragment &TextFragment, mut rects []LayoutRect) bool {
	if fragment.shadow != none || fragment.shadows.len > 0 || fragment.text_shadows.len > 0
		|| fragment.selection_style.text_shadows.len > 0 || fragment.background_images.len > 0
		|| fragment.paintable_fragment.orientation != .horizontal
		|| (fragment.text != '' && !fragment.baseline_set) { return false }
	mut outset := math.max(f64(0), fragment.outline_width + math.abs(fragment.outline_offset)) + 2
	if fragment.decoration != 'none' || fragment.selection_style.decoration_set {
		if !fragment.font_metrics_set { return false }
		outset += math.abs(fragment.baseline) + math.abs(fragment.font_ascent)
			+ math.abs(fragment.font_descent) + math.abs(fragment.glyph_height)
			+ math.abs(fragment.font_size) + math.abs(fragment.text_underline_offset)
			+ 4 * math.max(f64(1), math.abs(fragment.decoration_thickness))
	}
	left := fragment.x - fragment.padding.left - fragment.border.left - outset
	top := fragment.y - fragment.padding.top - fragment.border.top - outset
	right := fragment.x + fragment.width + fragment.padding.right + fragment.border.right + outset
	bottom := fragment.y + fragment.height + fragment.padding.bottom + fragment.border.bottom + outset
	rects << LayoutRect{left, top, right - left, bottom - top}
	if fragment.text == '' { return true }
	run := fragment.paintable_fragment.glyph_run or { return false }
	translation_y := text_fragment_paint_top(*fragment) + fragment.baseline
	if math.abs(fragment.x) > 1_000_000 || math.abs(translation_y) > 1_000_000 { return false }
	ink := run.bounding_box()
	rects << LayoutRect{fragment.x + f64(ink.x), translation_y + f64(ink.y),
		f64(ink.width), f64(ink.height)}
	return true
}

fn viewport_cached_entry_ink_is_outside(cache &ViewportEntryInkCache, index int,
	transform [6]f64, width f64, height f64, mut ink_probe PaintCommand) bool {
	entry := cache.entries[index]
	if !entry.bounded { return false }
	if entry.has_bounds && !disable_viewport_ink_bounds && !disable_direct_viewport_rect_culling
		&& viewport_rect_is_outside(entry.bounds, transform, width, height, mut ink_probe) {
		return true
	}
	for offset in 0 .. entry.count {
		if !viewport_rect_is_outside(cache.rects[entry.first + offset], transform,
			width, height, mut ink_probe) { return false }
	}
	return true
}
