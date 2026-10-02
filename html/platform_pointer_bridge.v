// Copyright (c) 2026, Ladybird contributors
// SPDX-License-Identifier: BSD-2-Clause
module html

import dom

fn platform_pointer_light_dismiss(event &dom.PointerEvent, node &dom.Node) {
	html_element_light_dismiss_open_popovers(event, node)
	html_dialog_element_light_dismiss_open_dialogs(event, node)
}
