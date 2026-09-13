module webaudio

import html

struct AudioWorkletInputObservation {
mut:
	start_frame u64
	had_gap     bool
	channel     []f32
	parameter   []f32
}

struct AudioWorkletOutputObservation {
mut:
	start_frame      u64
	processor_active bool
	channel          []f32
}

struct AudioWorkletPipeWakeObservation {
mut:
	calls int
}

struct AudioWorkletPipeFrameObservation {
mut:
	frames []u64
}

fn audio_worklet_pipe_config() AudioWorkletPipeConfig {
	return AudioWorkletPipeConfig{
		quantum_size: 4
		sample_rate: 48_000
		input_count: 1
		output_count: 1
		input_channel_capacity: [u32(2)]
		output_channel_capacity: [u32(2)]
		param_count: 2
		param_is_a_rate: [true, false]
		ring_capacity: 2
		prime_level: 1
	}
}

fn drain_audio_worklet_pipe_tasks() {
	mut event_loop := html.main_thread_event_loop()
	for event_loop.task_queue().has_runnable_tasks() {
		event_loop.process()
	}
}

fn test_audio_worklet_pipe_sizes_rings_for_device_latency() {
	sizing := AudioWorkletPipeConfig.ring_sizing_for_device_latency(100, 48_000, 128)
	assert sizing.ring_capacity == 64
	assert sizing.prime_level == 48
}

fn test_audio_worklet_pipe_moves_input_slots_and_counts_drops() {
	mut pipe := AudioWorkletPipe.create(audio_worklet_pipe_config()) or { panic(err) }
	assert pipe.try_push_input(fn (mut slot AudioWorkletInputSlot) {
		slot.set_start_frame(128)
		slot.set_had_gap(true)
		slot.set_actual_channel_count(0, 2)
		slot.set_input_channel(0, 0, [f32(1), 2, 3, 4])
		slot.set_input_channel(0, 1, [f32(5), 6, 7, 8])
		slot.set_param_block(0, [f32(0.1), 0.2, 0.3, 0.4])
		slot.set_param_block(1, [f32(9)])
	})
	assert pipe.try_push_input(fn (mut slot AudioWorkletInputSlot) {
		slot.set_start_frame(132)
	})
	assert !pipe.try_push_input(fn (_ mut AudioWorkletInputSlot) {})
	assert pipe.dropped_input_count() == 1
	mut observed := &AudioWorkletInputObservation{}
	assert pipe.try_pop_input(fn [mut observed] (slot AudioWorkletInputSlot) {
		observed.start_frame = slot.start_frame()
		observed.had_gap = slot.had_gap()
		observed.channel = slot.input_channel(0, 1).clone()
		observed.parameter = slot.param_block(1).clone()
	})
	assert observed.start_frame == 128
	assert observed.had_gap
	assert observed.channel == [f32(5), 6, 7, 8]
	assert observed.parameter == [f32(9)]
}

fn test_audio_worklet_pipe_moves_output_slots_and_counts_underruns() {
	mut pipe := AudioWorkletPipe.create(audio_worklet_pipe_config()) or { panic(err) }
	assert !pipe.try_pop_output(fn (_ AudioWorkletOutputSlot) {})
	assert pipe.underrun_count() == 1
	assert pipe.try_push_output(fn (mut slot AudioWorkletOutputSlot) {
		slot.set_start_frame(256)
		slot.set_processor_active(false)
		slot.set_actual_channel_count(0, 2)
		slot.set_output_channel(0, 0, [f32(1), 2, 3, 4])
		slot.set_output_channel(0, 1, [f32(5), 6, 7, 8])
	})
	mut observed := &AudioWorkletOutputObservation{
		processor_active: true
	}
	assert pipe.try_pop_output(fn [mut observed] (slot AudioWorkletOutputSlot) {
		observed.start_frame = slot.start_frame()
		observed.processor_active = slot.processor_active()
		observed.channel = slot.output_channel(0, 1).clone()
	})
	assert observed.start_frame == 256
	assert !observed.processor_active
	assert observed.channel == [f32(5), 6, 7, 8]
}

fn test_audio_worklet_pipe_masks_wrapped_slot_counters() {
	mut pipe := AudioWorkletPipe.create(audio_worklet_pipe_config()) or { panic(err) }
	assert pipe.input_slot(0) == 0
	assert pipe.input_slot(1) == 1
	assert pipe.input_slot(2) == 0
	assert pipe.output_slot(3) == 1

	assert pipe.try_push_input(fn (mut slot AudioWorkletInputSlot) {
		slot.set_start_frame(1)
	})
	assert pipe.try_pop_input(fn (_ AudioWorkletInputSlot) {})
	assert pipe.try_push_input(fn (mut slot AudioWorkletInputSlot) {
		slot.set_start_frame(2)
	})
	assert pipe.try_push_input(fn (mut slot AudioWorkletInputSlot) {
		slot.set_start_frame(3)
	})
	mut observed := &AudioWorkletPipeFrameObservation{}
	assert pipe.try_pop_input(fn [mut observed] (slot AudioWorkletInputSlot) {
		observed.frames << slot.start_frame()
	})
	assert pipe.try_pop_input(fn [mut observed] (slot AudioWorkletInputSlot) {
		observed.frames << slot.start_frame()
	})
	assert observed.frames == [u64(2), 3]
}

fn test_audio_worklet_pipe_primes_and_discards_output_lookahead() {
	mut config := audio_worklet_pipe_config()
	config.ring_capacity = 4
	config.prime_level = 2
	mut pipe := AudioWorkletPipe.create(config) or { panic(err) }
	pipe.prime_outputs_with_silence(2)
	assert pipe.output_occupancy() == 2
	assert pipe.try_push_output(fn (mut slot AudioWorkletOutputSlot) {
		slot.set_actual_channel_count(0, 1)
	})
	assert pipe.output_occupancy() == 3
	pipe.discard_outputs_down_to(1)
	assert pipe.output_occupancy() == 1
	mut observed := &AudioWorkletOutputObservation{}
	assert pipe.try_pop_output(fn [mut observed] (slot AudioWorkletOutputSlot) {
		observed.channel = slot.output_channel(0, 0).clone()
	})
	assert observed.channel == []f32{len: 4}
}

fn test_audio_worklet_pipe_coalesces_wakeups_and_honors_shutdown() {
	mut pipe := AudioWorkletPipe.create(audio_worklet_pipe_config()) or { panic(err) }
	pipe_pointer := pipe
	mut observed := &AudioWorkletPipeWakeObservation{}
	pipe.set_pump_callback(fn [mut observed, pipe_pointer] () {
		observed.calls++
		mut current_pipe := pipe_pointer
		current_pipe.clear_wakeup_flag()
	})
	pipe.request_wakeup()
	pipe.request_wakeup()
	drain_audio_worklet_pipe_tasks()
	assert observed.calls == 1
	pipe.request_wakeup()
	drain_audio_worklet_pipe_tasks()
	assert observed.calls == 2
	pipe.request_wakeup()
	pipe.request_shutdown()
	drain_audio_worklet_pipe_tasks()
	assert observed.calls == 2
	assert pipe.state() == .shut_down
}

fn test_audio_worklet_pipe_validates_configuration() {
	mut config := audio_worklet_pipe_config()
	config.ring_capacity = 3
	AudioWorkletPipe.create(config) or {
		assert err.msg().contains('power of two')
		return
	}
	assert false
}
