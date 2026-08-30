// Copyright (c) 2025-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of RenderingThread.{h,cpp}. The embedder owns the actual worker
// thread and Skia player; this command processor preserves command ordering,
// backing-store swaps, screenshot execution, and rasterization back pressure.
module html

pub struct RenderingRect {
pub:
	x      int
	y      int
	width  int
	height int
}

@[heap]
pub struct RenderingSurface {
pub:
	id int
pub mut:
	last_display_list_id int = -1
}

@[heap]
pub struct RenderingDisplayList {
pub:
	id int
}

pub struct RenderingScrollStateSnapshot {
pub:
	revision u64
}

pub type RenderingExecuteHook = fn (&RenderingDisplayList, RenderingScrollStateSnapshot, &RenderingSurface)

pub type RenderingPresentationCallback = fn (RenderingRect, int)

pub type RenderingScreenshotCallback = fn ()

struct UpdateDisplayListCommand {
	display_list &RenderingDisplayList
	scroll_state RenderingScrollStateSnapshot
}

struct UpdateBackingStoresCommand {
	front           ?&RenderingSurface
	back            ?&RenderingSurface
	front_bitmap_id int
	back_bitmap_id  int
}

struct ScreenshotCommand {
	target   &RenderingSurface
	callback ?RenderingScreenshotCallback
}

type RenderingCommand = ScreenshotCommand | UpdateBackingStoresCommand | UpdateDisplayListCommand

struct BackingStoreState {
mut:
	front           ?&RenderingSurface
	back            ?&RenderingSurface
	front_bitmap_id int = -1
	back_bitmap_id  int = -1
}

fn (state &BackingStoreState) is_valid() bool {
	return state.front != none && state.back != none
}

fn (mut state BackingStoreState) swap() {
	front := state.front
	front_id := state.front_bitmap_id
	state.front = state.back
	state.front_bitmap_id = state.back_bitmap_id
	state.back = front
	state.back_bitmap_id = front_id
}

@[heap]
pub struct RenderingThread {
mut:
	presentation_callback_      RenderingPresentationCallback
	execute_hook_               ?RenderingExecuteHook
	command_queue_              []RenderingCommand
	cached_display_list_        ?&RenderingDisplayList
	cached_scroll_state_        RenderingScrollStateSnapshot
	backing_stores_             BackingStoreState
	queued_rasterization_tasks_ int
	needs_present_              bool
	pending_viewport_rect_      RenderingRect
	started_                    bool
	exited_                     bool
}

pub fn RenderingThread.create(presentation_callback RenderingPresentationCallback) &RenderingThread {
	return &RenderingThread{
		presentation_callback_: presentation_callback
	}
}

pub fn (mut renderer RenderingThread) set_player(execute RenderingExecuteHook) {
	renderer.execute_hook_ = execute
}

pub fn (mut renderer RenderingThread) set_skia_player(execute RenderingExecuteHook) {
	renderer.set_player(execute)
}

pub fn (mut renderer RenderingThread) start() ! {
	if renderer.execute_hook_ == none {
		return error('RenderingThread requires a display-list player before start')
	}
	renderer.started_ = true
}

pub fn (mut renderer RenderingThread) exit() {
	renderer.exited_ = true
	renderer.command_queue_.clear()
}

pub fn (mut renderer RenderingThread) update_display_list(display_list &RenderingDisplayList, scroll_state RenderingScrollStateSnapshot) {
	renderer.command_queue_ << RenderingCommand(UpdateDisplayListCommand{
		display_list: display_list
		scroll_state: scroll_state
	})
}

pub fn (mut renderer RenderingThread) update_backing_stores(front ?&RenderingSurface, back ?&RenderingSurface, front_id int, back_id int) {
	renderer.command_queue_ << RenderingCommand(UpdateBackingStoresCommand{
		front:           front
		back:            back
		front_bitmap_id: front_id
		back_bitmap_id:  back_id
	})
}

pub fn (mut renderer RenderingThread) present_frame(viewport_rect RenderingRect) {
	renderer.needs_present_ = true
	renderer.pending_viewport_rect_ = viewport_rect
}

pub fn (mut renderer RenderingThread) request_screenshot(target &RenderingSurface, callback ?RenderingScreenshotCallback) {
	renderer.command_queue_ << RenderingCommand(ScreenshotCommand{
		target:   target
		callback: callback
	})
}

pub fn (mut renderer RenderingThread) process() {
	if !renderer.started_ || renderer.exited_ {
		return
	}
	commands := renderer.command_queue_.clone()
	renderer.command_queue_.clear()
	for command in commands {
		match command {
			UpdateDisplayListCommand {
				renderer.cached_display_list_ = command.display_list
				renderer.cached_scroll_state_ = command.scroll_state
			}
			UpdateBackingStoresCommand {
				renderer.backing_stores_ = BackingStoreState{
					front:           command.front
					back:            command.back
					front_bitmap_id: command.front_bitmap_id
					back_bitmap_id:  command.back_bitmap_id
				}
			}
			ScreenshotCommand {
				if display_list := renderer.cached_display_list_ {
					if execute := renderer.execute_hook_ {
						execute(display_list, renderer.cached_scroll_state_, command.target)
					}
					if callback := command.callback {
						callback()
					}
				}
			}
		}
	}
	if !renderer.needs_present_ || renderer.queued_rasterization_tasks_ > 1 {
		return
	}
	renderer.needs_present_ = false
	display_list := renderer.cached_display_list_ or { return }
	if !renderer.backing_stores_.is_valid() {
		return
	}
	back := renderer.backing_stores_.back or { return }
	if execute := renderer.execute_hook_ {
		execute(display_list, renderer.cached_scroll_state_, back)
	}
	rendered_bitmap_id := renderer.backing_stores_.back_bitmap_id
	renderer.backing_stores_.swap()
	renderer.queued_rasterization_tasks_++
	renderer.presentation_callback_(renderer.pending_viewport_rect_, rendered_bitmap_id)
}

pub fn (mut renderer RenderingThread) ready_to_paint() ! {
	if renderer.queued_rasterization_tasks_ < 1 || renderer.queued_rasterization_tasks_ > 2 {
		return error('RenderingThread has no queued rasterization task')
	}
	renderer.queued_rasterization_tasks_--
}

pub fn (renderer &RenderingThread) queued_rasterization_tasks() int {
	return renderer.queued_rasterization_tasks_
}

pub fn (renderer &RenderingThread) pending_command_count() int {
	return renderer.command_queue_.len
}
