// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause

// Translation of WebUI.cpp/.h.
module internals

import dom

pub struct WebUIMessage {
pub:
	name string
	data dom.JSValue
}

@[heap]
pub struct WebUI {
	InternalsBase
}

pub fn WebUI.create(platform &PlatformState) &WebUI {
	return &WebUI{
		InternalsBase: InternalsBase.new(platform)
	}
}

pub fn (ui &WebUI) send_message(name string, data dom.JSValue) {
	mut platform := unsafe { &PlatformState(ui.platform) }
	platform.web_ui_messages << WebUIMessage{name, data}
}
