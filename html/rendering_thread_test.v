module html

struct RenderingTestState {
mut:
	presented_ids []int
	executed_ids  []int
	screenshots   int
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
		surface.last_display_list_id = display_list.id
	})
	renderer.start()!
	front := &RenderingSurface{
		id: 1
	}
	back := &RenderingSurface{
		id: 2
	}
	display_list := &RenderingDisplayList{
		id: 7
	}
	renderer.update_display_list(display_list, RenderingScrollStateSnapshot{ revision: 3 })
	renderer.update_backing_stores(front, back, 10, 20)
	renderer.present_frame(RenderingRect{ width: 800, height: 600 })
	renderer.process()
	assert state.presented_ids == [20]
	assert state.executed_ids == [7]
	assert back.last_display_list_id == 7
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
	renderer.set_player(fn (_ &RenderingDisplayList, _ RenderingScrollStateSnapshot, _ &RenderingSurface) {})
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
