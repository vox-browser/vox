// Copyright (c) 2023-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/Transferable.h.
module bindings

import html

pub interface Transferable {
	transfer_steps(mut encoder TransferDataEncoder) !
	transfer_receiving_steps(mut decoder TransferDataDecoder) !
	primary_interface() html.TransferType
	is_detached() bool
	set_detached(detached bool)
}

pub struct TransferableState {
mut:
	detached_ bool
}

pub fn (state &TransferableState) is_detached() bool {
	return state.detached_
}

pub fn (mut state TransferableState) set_detached(detached bool) {
	state.detached_ = detached
}
