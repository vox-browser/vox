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
struct GamepadHapticsCompletionSteps {
	promise &HapticPromise
	queued  bool
}

fn resolve_haptics_promise(promise &HapticPromise, result GamepadHapticsResult) {
	mut target := unsafe { &HapticPromise(promise) }
	target.state = .fulfilled
	target.result = result
}

fn create_queued_haptics_completion_steps(promise &HapticPromise) &GamepadHapticsCompletionSteps {
	return &GamepadHapticsCompletionSteps{
		promise: promise
		queued: true
	}
}

fn create_haptics_completion_steps(promise &HapticPromise) &GamepadHapticsCompletionSteps {
	return &GamepadHapticsCompletionSteps{
		promise: promise
	}
}

fn (steps &GamepadHapticsCompletionSteps) complete(result GamepadHapticsResult) {
	// Queued completion is run at this explicit event-loop boundary in the V
	// host, while direct completion is used by reset().
	_ = steps.queued
	resolve_haptics_promise(steps.promise, result)
}

@[heap]
pub struct GamepadHapticActuator {
	gamepad &Gamepad
pub mut:
	effects_                  []GamepadHapticEffectType
	playing_                  ?&HapticPromise
	playing_completion_steps_ ?&GamepadHapticsCompletionSteps
	pending_type_             ?GamepadHapticEffectType
	pending_params_           GamepadEffectParameters
}

pub fn GamepadHapticActuator.create(pad &Gamepad) &GamepadHapticActuator {
	mut effects := []GamepadHapticEffectType{}
	if pad.device.supports_dual_rumble { effects << .dual_rumble }
	if pad.device.supports_trigger_rumble { effects << .trigger_rumble }
	return &GamepadHapticActuator{
		gamepad: pad
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

pub fn is_valid_effect(effect_type GamepadHapticEffectType, params GamepadEffectParameters) bool {
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

pub fn (actuator &GamepadHapticActuator) is_valid_effect(effect_type GamepadHapticEffectType, params GamepadEffectParameters) bool {
	_ = actuator
	return is_valid_effect(effect_type, params)
}

pub fn (actuator &GamepadHapticActuator) can_play_effect_with_type(effect_type GamepadHapticEffectType) bool {
	return effect_type in actuator.effects_
}

pub fn valid_effect(effect_type GamepadHapticEffectType, params GamepadEffectParameters) bool {
	return is_valid_effect(effect_type, params)
}

fn rejected_haptic_promise(message string) &HapticPromise {
	return &HapticPromise{
		state: .rejected
		error_: message
	}
}

pub fn (mut actuator GamepadHapticActuator) play_effect(effect_type GamepadHapticEffectType, params GamepadEffectParameters, document_active bool, document_visible bool) &HapticPromise {
	if !actuator.is_valid_effect(effect_type, params) {
		return rejected_haptic_promise('TypeError: Invalid effect')
	}
	if !document_active || !document_visible {
		return rejected_haptic_promise('InvalidStateError: Haptics are not allowed in a hidden document')
	}
	if !actuator.can_play_effect_with_type(effect_type) {
		return rejected_haptic_promise('NotSupportedError: Gamepad does not support this effect')
	}
	if old_steps := actuator.playing_completion_steps_ {
		old_steps.complete(.preempted)
		actuator.playing_ = none
		actuator.playing_completion_steps_ = none
		actuator.clear_playing_effect_timers()
	}
	promise := &HapticPromise{
		state: .pending
	}
	actuator.playing_ = promise
	actuator.playing_completion_steps_ = create_queued_haptics_completion_steps(promise)
	actuator.pending_type_ = effect_type
	actuator.pending_params_ = params
	return promise
}

// Called after startDelay by the platform timer. It issues the effect and then
// represents the duration timer firing, without depending on wall-clock tests.
pub fn (mut actuator GamepadHapticActuator) complete_pending_effect() bool {
	mut promise := actuator.playing_ or { return false }
	effect_type := actuator.pending_type_ or { return false }
	succeeded := actuator.issue_haptic_effect(effect_type, actuator.pending_params_)
	if completion_steps := actuator.playing_completion_steps_ {
		completion_steps.complete(.complete)
	} else {
		resolve_haptics_promise(promise, .complete)
	}
	actuator.playing_ = none
	actuator.playing_completion_steps_ = none
	actuator.clear_playing_effect_timers()
	return succeeded
}

pub fn (mut actuator GamepadHapticActuator) issue_haptic_effect(effect_type GamepadHapticEffectType, params GamepadEffectParameters) bool {
	mut device := unsafe { &Device(actuator.gamepad.sdl_gamepad()) }
	succeeded := match effect_type {
		.dual_rumble {
			device.issue_dual_rumble(magnitude_to_u16(params.strong_magnitude), magnitude_to_u16(params.weak_magnitude))
		}
		.trigger_rumble {
			device.issue_trigger_rumble(magnitude_to_u16(params.left_trigger), magnitude_to_u16(params.right_trigger))
		}
	}
	match effect_type {
		.dual_rumble { device.issue_dual_rumble(0, 0) }
		.trigger_rumble { device.issue_trigger_rumble(0, 0) }
	}
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
	reset_completion_steps := create_haptics_completion_steps(reset_promise)
	if mut playing := actuator.playing_ {
		if actuator.stop_haptic_effects() {
			if completion_steps := actuator.playing_completion_steps_ {
				completion_steps.complete(.preempted)
			} else {
				resolve_haptics_promise(playing, .preempted)
			}
			actuator.playing_ = none
			actuator.playing_completion_steps_ = none
			actuator.clear_playing_effect_timers()
		}
		reset_completion_steps.complete(.complete)
	}
	return reset_promise
}

pub fn (mut actuator GamepadHapticActuator) document_became_hidden() {
	if mut playing := actuator.playing_ {
		if completion_steps := actuator.playing_completion_steps_ {
			completion_steps.complete(.preempted)
		} else {
			resolve_haptics_promise(playing, .preempted)
		}
		actuator.stop_haptic_effects()
	}
	actuator.playing_ = none
	actuator.playing_completion_steps_ = none
	actuator.clear_playing_effect_timers()
}

pub fn (mut actuator GamepadHapticActuator) clear_playing_effect_timers() {
	actuator.pending_type_ = none
	actuator.pending_params_ = GamepadEffectParameters{}
}
