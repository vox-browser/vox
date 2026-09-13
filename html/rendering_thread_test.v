module html

struct RenderingTestState {
mut:
	presented_ids []int
	executed_ids  []int
	published_ids []int
	allocated_ids []int
	screenshots   int
}

fn record_rendering_backing_store_allocation(target voidptr, front_id int, back_id int) {
	mut state := unsafe { &RenderingTestState(target) }
	state.allocated_ids << front_id
	state.allocated_ids << back_id
}

fn test_rendering_thread_processes_commands_swaps_and_applies_back_pressure() {
	state := &RenderingTestState{}
	mut renderer := RenderingThread.create(fn [state] (_ RenderingRect, bitmap_id int) {
		mut mutable_state := unsafe { &RenderingTestState(state) }
		mutable_state.presented_ids << bitmap_id
	})
	renderer.set_player(fn [state] (display_list &RenderingDisplayList, _ RenderingScrollStateSnapshot, mut surface RenderingSurface) {
		mut mutable_state := unsafe { &RenderingTestState(state) }
		mutable_state.executed_ids << display_list.id
		assert surface.size == RenderingSize{ width: 800, height: 600 }
		surface.last_display_list_id = display_list.id
	})
	renderer.start()!
	display_list := &RenderingDisplayList{
		id: 7
	}
	renderer.update_display_list(display_list, RenderingScrollStateSnapshot{ revision: 3 })
	renderer.update_backing_stores(RenderingSize{ width: 800, height: 600 }, 10, 20, RenderingBackingStoreAllocation{
		target: voidptr(state)
		callback: record_rendering_backing_store_allocation
	})
	assert state.allocated_ids.len == 0
	renderer.present_frame(RenderingRect{ width: 800, height: 600 })
	renderer.process()
	assert state.allocated_ids == [10, 20]
	assert state.presented_ids == [20]
	assert state.executed_ids == [7]
	assert renderer.queued_rasterization_tasks() == 1

	renderer.present_frame(RenderingRect{ width: 800, height: 600 })
	renderer.process()
	assert state.presented_ids == [20, 10]
	assert renderer.queued_rasterization_tasks() == 2
	renderer.present_frame(RenderingRect{ width: 800, height: 600 })
	renderer.process()
	assert state.presented_ids.len == 2
	renderer.ready_to_paint()!
	renderer.process()
	assert state.presented_ids.len == 3
}

fn test_rendering_thread_screenshot_and_lifecycle() {
	state := &RenderingTestState{}
	mut renderer := RenderingThread.create(fn (_ RenderingRect, _ int) {})
	renderer.set_skia_player(fn (_ &RenderingDisplayList, _ RenderingScrollStateSnapshot, _ &RenderingSurface) {})
	renderer.start()!
	renderer.update_display_list(&RenderingDisplayList{ id: 1 }, RenderingScrollStateSnapshot{})
	target := &RenderingSurface{
		id: 9
	}
	renderer.request_screenshot(target, fn [state] () {
		mut mutable_state := unsafe { &RenderingTestState(state) }
		mutable_state.screenshots++
	})
	assert renderer.pending_command_count() == 2
	renderer.process()
	assert state.screenshots == 1
	renderer.exit()
	assert renderer.pending_command_count() == 0
}

fn test_rendering_thread_serializes_external_content_surface_clears() {
	state := &RenderingTestState{}
	mut renderer := RenderingThread.create(fn [state] (_ RenderingRect, bitmap_id int) {
		mut mutable_state := unsafe { &RenderingTestState(state) }
		mutable_state.presented_ids << bitmap_id
	})
	renderer.set_skia_player(fn [state] (display_list &RenderingDisplayList, _ RenderingScrollStateSnapshot, mut surface RenderingSurface) {
		assert !surface.context_is_locked()
		assert surface.size == RenderingSize{ width: 320, height: 200 }
		assert surface.transparent_clear_count() == 1
		assert surface.last_clear_was_serialized()
		mut mutable_state := unsafe { &RenderingTestState(state) }
		mutable_state.executed_ids << display_list.id
	})
	renderer.set_presentation_mode(RenderingPublishToExternalContent{
		publish: fn [state] (surface &RenderingSurface) {
			mut mutable_state := unsafe { &RenderingTestState(state) }
			mutable_state.published_ids << surface.id
		}
	})
	renderer.start()!
	renderer.update_display_list(&RenderingDisplayList{ id: 8 }, RenderingScrollStateSnapshot{})
	renderer.update_backing_stores(RenderingSize{ width: 320, height: 200 }, 10, 20, none)
	renderer.present_frame(RenderingRect{ width: 320, height: 200 })

	renderer.process()

	assert state.executed_ids == [8]
	assert state.published_ids == [20]
	assert state.presented_ids.len == 0
	assert renderer.queued_rasterization_tasks() == 0
}
