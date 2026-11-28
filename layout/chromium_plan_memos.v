module layout

import os
import platform

// Same-binary control: walk every box's ancestors again while collecting
// layerization metadata.
const disable_raster_plan_memos = os.getenv('VOX_DISABLE_RASTER_PLAN_MEMOS') != ''

// Hit-test metadata visits every box of the viewport projection on each
// raster layer plan, and each visit walked the box's visual contexts twice
// (its clip and its compositor effect scope) and its layout ancestors once
// (its paint client): about 60% of every plan rebuild, which every animation
// frame performs. All three depend only on the context or the layout node,
// and the tree, scroll snapshot, compositor bounds and layout ancestry stay
// fixed during one layerization, so each is resolved once per layerization.
struct ChromiumRasterPlanMemos {
mut:
	active       bool
	generation   u32
	clip_stamps  []u32
	clips        []CompatibilityVisualContextClip
	scope_stamps []u32
	scopes       []u64
	clients      map[u64]u64
}

// Starts memoizing for one layerization of a tree with `context_count`
// visual contexts. Plan building runs in persistent storage.
fn (mut memos ChromiumRasterPlanMemos) begin(context_count int) {
	memos.active = !disable_raster_plan_memos
	memos.generation++
	if memos.generation == 0 {
		memos.clip_stamps = []u32{}
		memos.scope_stamps = []u32{}
		memos.generation = 1
	}
	if memos.clip_stamps.len < context_count {
		persistent := platform.enter_persistent()
		memos.clip_stamps = []u32{len: context_count}
		memos.clips = []CompatibilityVisualContextClip{len: context_count}
		memos.scope_stamps = []u32{len: context_count}
		memos.scopes = []u64{len: context_count}
		platform.leave_persistent(persistent)
	}
	memos.clients.clear()
}

fn (mut memos ChromiumRasterPlanMemos) end() {
	memos.active = false
}

fn (mut memos ChromiumRasterPlanMemos) context_clip(result &DocumentLayoutResult, context int) CompatibilityVisualContextClip {
	if !memos.active || context < 0 || context >= memos.clip_stamps.len {
		return compatibility_visual_context_clip(&result.visual_context_tree, context,
			result.scroll_state_snapshot)
	}
	if memos.clip_stamps[context] != memos.generation {
		memos.clips[context] = compatibility_visual_context_clip(&result.visual_context_tree, context,
			result.scroll_state_snapshot)
		memos.clip_stamps[context] = memos.generation
	}
	return memos.clips[context]
}

// The nearest context at or above `context` that owns compositor bounds.
fn (mut memos ChromiumRasterPlanMemos) effect_scope(result &DocumentLayoutResult, context int,
	compositor_bounds map[u64]LayoutRect) u64 {
	cached := memos.active && context >= 0 && context < memos.scope_stamps.len
	if cached && memos.scope_stamps[context] == memos.generation { return memos.scopes[context] }
	mut scope := u64(0)
	mut ancestor := context
	for ancestor > 0 && ancestor < result.visual_context_tree.nodes.len {
		if u64(ancestor) in compositor_bounds {
			scope = u64(ancestor)
			break
		}
		ancestor = result.visual_context_tree.nodes[ancestor].parent_index
	}
	if cached {
		memos.scopes[context] = scope
		memos.scope_stamps[context] = memos.generation
	}
	return scope
}

fn (mut memos ChromiumRasterPlanMemos) paint_client(box &BlockBox) u64 {
	if !memos.active || box.layout_handle == unsafe { nil } { return chromium_paint_client(box) }
	key := u64(box.layout_handle)
	if client := memos.clients[key] { return client }
	client := chromium_paint_client(box)
	memos.clients[key] = client
	return client
}
