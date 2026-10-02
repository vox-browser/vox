// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
@[has_globals]
module dom

pub type PointerLightDismissCallback = fn (&PointerEvent, &Node)

__global (
	pointer_light_dismiss_callback PointerLightDismissCallback
)

pub fn install_pointer_light_dismiss_callback(callback PointerLightDismissCallback) {
	pointer_light_dismiss_callback = callback
}

pub fn run_pointer_light_dismiss(event &PointerEvent, node &Node) {
	if pointer_light_dismiss_callback != unsafe { nil } {
		pointer_light_dismiss_callback(event, node)
	}
}

pub fn run_focusing_steps_for_node(node &Node, fallback ?&Node, trigger FocusTrigger) {
	if dom_run_focusing_steps != unsafe { nil } { dom_run_focusing_steps(node, fallback, trigger) }
}
