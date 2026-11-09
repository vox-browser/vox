module layout

import math
import os
import painting
import platform

const disable_hit_test_culling = os.getenv('VOX_DISABLE_HIT_TEST_CULLING') != ''
const hit_test_culling_block = 32
// Containment uses the same local point as each step's own test; widen the
// cached bounds slightly so edge-inclusive and rounded comparisons stay inside.
const hit_test_culling_slop = 1.0

enum HitTestStepReach {
	// No exact hit is possible from this step.
	never
	// The step can only produce an exact hit inside `rect`, in `context`.
	bounded
	// Test the step every time (retained scrollbar/resizer chrome).
	always
}

struct HitTestStepBounds {
	reach   HitTestStepReach
	context int
	left    f64
	top     f64
	right   f64
	bottom  f64
}

// Union over a run of steps. A query skips the run when its point lies outside
// the union of steps sharing one context. Runs with mixed contexts or chrome
// steps are always scanned.
struct HitTestBlockBounds {
	scan    bool
	empty   bool
	context int
	left    f64
	top     f64
	right   f64
	bottom  f64
}

// Built once per paint revision and hit plan. Chromium's hit test skips a
// subtree whose overflow rect misses the point (LayoutBox::MayIntersect); the
// retained plan is flat, so the equivalent prunes contiguous runs of its steps.
struct HitTestCullingCache {
mut:
	valid    bool
	revision u64
	steps_data voidptr
	steps_len  int
	contexts_data voidptr
	contexts_len  int
	steps    []HitTestStepBounds
	blocks   []HitTestBlockBounds
}

fn (bounds HitTestStepBounds) contains(point painting.Point) bool {
	return point.x >= bounds.left && point.x <= bounds.right && point.y >= bounds.top
		&& point.y <= bounds.bottom
}

fn (bounds HitTestBlockBounds) contains(point painting.Point) bool {
	return point.x >= bounds.left && point.x <= bounds.right && point.y >= bounds.top
		&& point.y <= bounds.bottom
}

fn hit_test_bounds_from_rect(context int, x f64, y f64, width f64, height f64) HitTestStepBounds {
	if math.is_nan(x) || math.is_nan(y) || math.is_nan(width) || math.is_nan(height)
		|| math.is_inf(x, 0) || math.is_inf(y, 0) || math.is_inf(width, 0) || math.is_inf(height, 0) {
		return HitTestStepBounds{ reach: .always }
	}
	return HitTestStepBounds{
		reach:   .bounded
		context: context
		left:    x - hit_test_culling_slop
		top:     y - hit_test_culling_slop
		right:   x + math.max(width, 0) + hit_test_culling_slop
		bottom:  y + math.max(height, 0) + hit_test_culling_slop
	}
}

// Mirrors the exact-hit paths of viewport_hit_test(): every candidate below
// needs the step's mapped point inside its border box or one of its line
// fragments. Steps that only ever produce candidates for text-cursor queries,
// or never produce one, are `never` here.
fn hit_test_step_bounds(step CompatibilityPaintStep) HitTestStepBounds {
	box := step.box
	match step.phase {
		.overlay {
			// Chrome falls back to the unmapped point when its context rejects
			// it, so retained scrollbars and resizers are always tested.
			if box.overlay != none { return HitTestStepBounds{ reach: .always } }
			// The empty-editable preamble answers text-cursor queries only.
			return HitTestStepBounds{ reach: .never }
		}
		.foreground {
			if !box.paintable_with_lines { return HitTestStepBounds{ reach: .never } }
			context := if box.stacking_context {
				box.accumulated_visual_context_index
			} else {
				box.accumulated_visual_context_for_descendants_idx
			}
			mut found := false
			mut left := f64(0)
			mut top := f64(0)
			mut right := f64(0)
			mut bottom := f64(0)
			for line_index in 0 .. box.lines.len {
				line := unsafe { &box.lines[line_index] }
				for fragment_index in 0 .. line.fragments.len {
					fragment := unsafe { &line.fragments[fragment_index].paintable_fragment }
					x := fragment.offset.x + fragment.containing_block_offset.x
					y := fragment.offset.y + fragment.containing_block_offset.y
					if !found {
						left, top = x, y
						right, bottom = x + fragment.size.width, y + fragment.size.height
						found = true
						continue
					}
					left = math.min(left, x)
					top = math.min(top, y)
					right = math.max(right, x + fragment.size.width)
					bottom = math.max(bottom, y + fragment.size.height)
				}
			}
			if !found { return HitTestStepBounds{ reach: .never } }
			return hit_test_bounds_from_rect(context, left, top, right - left, bottom - top)
		}
		.border {
			if box.has_svg_hit_geometry() {
				bounds := box.svg_hit_test_bounds()
				return hit_test_bounds_from_rect(box.accumulated_visual_context_index,
					bounds.x, bounds.y, bounds.width, bounds.height)
			}
			border := box.border_box()
			return hit_test_bounds_from_rect(box.accumulated_visual_context_index, border.x,
				border.y, border.width, border.height)
		}
		else {
			return HitTestStepBounds{ reach: .never }
		}
	}
}

fn refresh_hit_test_culling(mut result DocumentLayoutResult) bool {
	revision := result.document.paint_content_revision()
	mut cache := &result.hit_test_culling
	if cache.valid && cache.revision == revision && cache.steps_data == result.hit_test_steps.data
		&& cache.steps_len == result.hit_test_steps.len
		&& cache.contexts_data == result.visual_context_tree.nodes.data
		&& cache.contexts_len == result.visual_context_tree.nodes.len {
		return true
	}
	// Like the viewport ink cache, the bounds outlive any transient arena that
	// is active when the first query after a paint change arrives.
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	cache.valid = false
	cache.steps.clear()
	cache.blocks.clear()
	for step in result.hit_test_steps {
		cache.steps << hit_test_step_bounds(step)
	}
	for start := 0; start < cache.steps.len; start += hit_test_culling_block {
		end := math.min(start + hit_test_culling_block, cache.steps.len)
		cache.blocks << hit_test_block_bounds(cache.steps[start..end])
	}
	cache.revision = revision
	cache.steps_data = result.hit_test_steps.data
	cache.steps_len = result.hit_test_steps.len
	cache.contexts_data = result.visual_context_tree.nodes.data
	cache.contexts_len = result.visual_context_tree.nodes.len
	cache.valid = true
	return true
}

fn hit_test_block_bounds(steps []HitTestStepBounds) HitTestBlockBounds {
	mut context := -1
	mut found := false
	mut left := f64(0)
	mut top := f64(0)
	mut right := f64(0)
	mut bottom := f64(0)
	for bounds in steps {
		match bounds.reach {
			.never { continue }
			.always { return HitTestBlockBounds{ scan: true } }
			.bounded {}
		}
		if !found {
			context = bounds.context
			left, top, right, bottom = bounds.left, bounds.top, bounds.right, bounds.bottom
			found = true
			continue
		}
		if bounds.context != context { return HitTestBlockBounds{ scan: true } }
		left = math.min(left, bounds.left)
		top = math.min(top, bounds.top)
		right = math.max(right, bounds.right)
		bottom = math.max(bottom, bounds.bottom)
	}
	if !found { return HitTestBlockBounds{ empty: true } }
	return HitTestBlockBounds{
		context: context
		left:    left
		top:     top
		right:   right
		bottom:  bottom
	}
}

// Whether a step could produce an exact hit for the memo's point.
fn (cache &HitTestCullingCache) step_may_hit(index int, mut memo CompatibilityHitPointMemo) bool {
	bounds := cache.steps[index]
	return match bounds.reach {
		.never {
			false
		}
		.always {
			true
		}
		.bounded {
			local := memo.local(bounds.context) or { return false }
			bounds.contains(local)
		}
	}
}

fn (cache &HitTestCullingCache) block_may_hit(index int, mut memo CompatibilityHitPointMemo) bool {
	block := cache.blocks[index]
	if block.scan { return true }
	if block.empty { return false }
	local := memo.local(block.context) or { return false }
	return block.contains(local)
}
