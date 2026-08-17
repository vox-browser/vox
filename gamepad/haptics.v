// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of GamepadHapticActuator.cpp/.h. Scheduling is deliberately
// driven by complete_pending_effect(), the embedder timer boundary.
module gamepad

const max_vibration_duration = u64(5000)

pub enum GamepadHapticsResult {
	complete
	preempted
}
pub enum GamepadHapticEffectType {
	dual_rumble
	trigger_rumble
}
pub enum HapticPromiseState {
	pending
	fulfilled
	rejected
}

pub struct GamepadEffectParameters {
pub:
	duration         u64
	start_delay      u64
	strong_magnitude f64
	weak_magnitude   f64
	left_trigger     f64
	right_trigger    f64
}

@[heap]
pub struct HapticPromise {
pub mut:
	state  HapticPromiseState
	result ?GamepadHapticsResult
	error_ string
}

@[heap]
pub struct GamepadHapticActuator {
	gamepad &Gamepad
pub mut:
	effects_        []GamepadHapticEffectType
	playing_        ?&HapticPromise
	pending_type_   ?GamepadHapticEffectType
	pending_params_ GamepadEffectParameters
}

pub fn GamepadHapticActuator.create(pad &Gamepad) &GamepadHapticActuator {
	mut effects := []GamepadHapticEffectType{}
	if pad.device.supports_dual_rumble { effects << .dual_rumble }
	if pad.device.supports_trigger_rumble { effects << .trigger_rumble }
	return &GamepadHapticActuator{
		gamepad:  pad
		effects_: effects
	}
}

pub fn (actuator &GamepadHapticActuator) effects() []GamepadHapticEffectType {
	return actuator.effects_.clone()
}

fn valid_magnitude(value f64) bool {
	// Keep the specification's comparison-only range check. In particular,
	// NaN compares neither less than zero nor greater than one and is accepted.
	return !(value < 0.0 || value > 1.0)
}

pub fn valid_effect(effect_type GamepadHapticEffectType, params GamepadEffectParameters) bool {
	if params.duration > max_vibration_duration
		|| params.start_delay > max_vibration_duration - params.duration {
		return false
	}
	if !valid_magnitude(params.strong_magnitude) || !valid_magnitude(params.weak_magnitude) {
		return false
	}
	if effect_type == .trigger_rumble
		&& (!valid_magnitude(params.left_trigger) || !valid_magnitude(params.right_trigger)) {
		return false
	}
	return true
}

fn rejected_haptic_promise(message string) &HapticPromise {
	return &HapticPromise{
		state:  .rejected
		error_: message
	}
}

pub fn (mut actuator GamepadHapticActuator) play_effect(effect_type GamepadHapticEffectType, params GamepadEffectParameters, document_active bool, document_visible bool) &HapticPromise {
	if !valid_effect(effect_type, params) {
		return rejected_haptic_promise('TypeError: Invalid effect')
	}
	if !document_active || !document_visible {
		return rejected_haptic_promise('InvalidStateError: Haptics are not allowed in a hidden document')
	}
	if mut old := actuator.playing_ {
		old.state = .fulfilled
		old.result = .preempted
		actuator.playing_ = none
		actuator.pending_type_ = none
	}
	if effect_type !in actuator.effects_ {
		return rejected_haptic_promise('NotSupportedError: Gamepad does not support this effect')
	}
	promise := &HapticPromise{
		state: .pending
	}
	actuator.playing_ = promise
	actuator.pending_type_ = effect_type
	actuator.pending_params_ = params
	return promise
}

// Called after startDelay by the platform timer. It issues the effect and then
// represents the duration timer firing, without depending on wall-clock tests.
pub fn (mut actuator GamepadHapticActuator) complete_pending_effect() bool {
	mut promise := actuator.playing_ or { return false }
	effect_type := actuator.pending_type_ or { return false }
	params := actuator.pending_params_
	mut device := unsafe { &Device(actuator.gamepad.device) }
	succeeded := match effect_type {
		.dual_rumble {
			device.issue_dual_rumble(magnitude_to_u16(params.strong_magnitude),
				magnitude_to_u16(params.weak_magnitude))
		}
		.trigger_rumble {
			device.issue_trigger_rumble(magnitude_to_u16(params.left_trigger),
				magnitude_to_u16(params.right_trigger))
		}
	}
	// The duration callback stops only the effect that it started. Platform
	// failures do not reject the already-accepted playEffect() promise.
	match effect_type {
		.dual_rumble { device.issue_dual_rumble(0, 0) }
		.trigger_rumble { device.issue_trigger_rumble(0, 0) }
	}
	promise.state = .fulfilled
	promise.result = .complete
	actuator.playing_ = none
	actuator.pending_type_ = none
	return succeeded
}

fn magnitude_to_u16(value f64) u16 {
	return u16(value * 65535.0)
}

fn (mut actuator GamepadHapticActuator) stop_haptic_effects() bool {
	mut device := unsafe { &Device(actuator.gamepad.device) }
	mut result := true
	if GamepadHapticEffectType.dual_rumble in actuator.effects_ {
		result = device.issue_dual_rumble(0, 0) && result
	}
	if GamepadHapticEffectType.trigger_rumble in actuator.effects_ {
		result = device.issue_trigger_rumble(0, 0) && result
	}
	return result
}

pub fn (mut actuator GamepadHapticActuator) reset(document_active bool, document_visible bool) &HapticPromise {
	if !document_active || !document_visible {
		return rejected_haptic_promise('InvalidStateError: Haptics are not allowed in a hidden document')
	}
	mut reset_promise := &HapticPromise{
		state: .pending
	}
	if mut playing := actuator.playing_ {
		if actuator.stop_haptic_effects() {
			playing.state = .fulfilled
			playing.result = .preempted
			actuator.playing_ = none
			actuator.pending_type_ = none
		}
		reset_promise.state = .fulfilled
		reset_promise.result = .complete
	}
	return reset_promise
}

pub fn (mut actuator GamepadHapticActuator) document_became_hidden() {
	if mut playing := actuator.playing_ {
		playing.state = .fulfilled
		playing.result = .preempted
		actuator.stop_haptic_effects()
	}
	actuator.playing_ = none
	actuator.pending_type_ = none
}
