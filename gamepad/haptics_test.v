module gamepad

import math

fn test_haptics_validate_complete_preempt_reset_and_visibility() {
	device := new_standard_virtual_device(1, 'haptic')
	pad := Gamepad.create(device, 0, 0)
	mut actuator := pad.vibration_actuator()
	assert actuator.effects() == [.dual_rumble, .trigger_rumble]
	invalid :=
		actuator.play_effect(.dual_rumble, GamepadEffectParameters{ duration: 5001 }, true, true)
	assert invalid.state == .rejected
	assert invalid.error_.starts_with('TypeError')
	hidden := actuator.play_effect(.dual_rumble, GamepadEffectParameters{}, true, false)
	assert hidden.state == .rejected
	first := actuator.play_effect(.dual_rumble, GamepadEffectParameters{
		duration:         20
		strong_magnitude: 0.5
		weak_magnitude:   0.25
	}, true, true)
	assert first.state == .pending
	second := actuator.play_effect(.trigger_rumble, GamepadEffectParameters{
		duration:      20
		left_trigger:  1
		right_trigger: 0.5
	}, true, true)
	assert first.state == .fulfilled
	assert first.result? == .preempted
	assert actuator.complete_pending_effect()
	assert second.state == .fulfilled
	assert second.result? == .complete
	// Preemption cancels the pending timer without touching the device. The
	// duration callback stops only the effect it issued.
	assert device.received_rumble.len == 0
	assert device.received_trigger_rumble.len == 2
	idle_reset := actuator.reset(true, true)
	// This intentionally preserves the current upstream behavior: reset() has
	// no resolution path when there is no playing effect.
	assert idle_reset.state == .pending
	pending :=
		actuator.play_effect(.dual_rumble, GamepadEffectParameters{ duration: 1 }, true, true)
	reset := actuator.reset(true, true)
	assert pending.result? == .preempted
	assert reset.result? == .complete
	pending2 :=
		actuator.play_effect(.dual_rumble, GamepadEffectParameters{ duration: 1 }, true, true)
	actuator.document_became_hidden()
	assert pending2.result? == .preempted
}

fn test_haptics_unsupported_effect_and_overflow_safe_duration() {
	device := &Device{
		id:   1
		name: 'no rumble'
	}
	pad := Gamepad.create(device, 0, 0)
	mut actuator := pad.vibration_actuator()
	unsupported := actuator.play_effect(.dual_rumble, GamepadEffectParameters{}, true, true)
	assert unsupported.state == .rejected
	assert unsupported.error_.starts_with('NotSupportedError')
	assert !valid_effect(.dual_rumble, GamepadEffectParameters{ duration: max_u64, start_delay: 1 })
	assert !valid_effect(.trigger_rumble, GamepadEffectParameters{ left_trigger: -0.1 })
	assert valid_effect(.dual_rumble, GamepadEffectParameters{
		strong_magnitude: math.nan()
	})
}

fn test_haptic_platform_failure_still_completes_play_promise() {
	mut device := new_standard_virtual_device(2, 'disconnected')
	pad := Gamepad.create(device, 0, 0)
	mut actuator := pad.vibration_actuator()
	promise :=
		actuator.play_effect(.dual_rumble, GamepadEffectParameters{ duration: 1 }, true, true)
	device.connected = false
	assert !actuator.complete_pending_effect()
	assert promise.state == .fulfilled
	assert promise.result? == .complete

	mut reset_device := new_standard_virtual_device(3, 'reset failure')
	reset_pad := Gamepad.create(reset_device, 0, 0)
	mut reset_actuator := reset_pad.vibration_actuator()
	playing := reset_actuator.play_effect(.dual_rumble, GamepadEffectParameters{ duration: 1 },
		true, true)
	reset_device.connected = false
	reset := reset_actuator.reset(true, true)
	assert reset.state == .fulfilled
	assert reset.result? == .complete
	assert playing.state == .pending
	assert reset_actuator.playing_ != none
}
