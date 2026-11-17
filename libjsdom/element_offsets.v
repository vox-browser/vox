// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import html
import libjs
import platform

fn (mut host Host) install_element_offsets() {
	mut prototype := host.html_element_prototype
	for name in ['offsetParent', 'offsetLeft', 'offsetTop', 'offsetWidth', 'offsetHeight'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			native := host.html_element_receiver(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			if name == 'offsetParent' {
				mut owner := unsafe { &Host(host) }
				return if parent := html.html_element_offset_parent(native) {
					owner.wrap_node(parent.as_node())
				} else {
					libjs.js_null()
				}
			}
			return libjs.Value.from_f64(f64(match name {
				'offsetLeft' { html.html_element_offset_left(native) }
				'offsetTop' { html.html_element_offset_top(native) }
				'offsetWidth' { html.html_element_offset_width(native) }
				else { html.html_element_offset_height(native) }
			}))
		}, unsafe { nil })
	}
	mut element := host.element_prototype
	for name in ['clientLeft', 'clientTop', 'clientWidth', 'clientHeight', 'scrollWidth', 'scrollHeight'] {
		host.accessor(mut element, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut native := host.element(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			return libjs.Value.from_f64(f64(match name {
				'clientLeft' { native.client_left() }
				'clientTop' { native.client_top() }
				'clientWidth' { native.client_width() }
				'clientHeight' { native.client_height() }
				'scrollWidth' { native.scroll_width() }
				else { native.scroll_height() }
			}))
		}, unsafe { nil })
	}
	host.install_element_scrolling()
}
