// SPDX-License-Identifier: BSD-2-Clause
module libjsdom

import dom
import libjs
import platform

fn (mut host Host) element_scroll(mut vm libjs.VM, name string) !libjs.Value {
	mut element := host.element(mut vm)!
	persistent := platform.enter_persistent()
	defer { platform.leave_persistent(persistent) }
	options := scroll_options(mut vm)!
	behavior := match options.behavior {
		.auto_ { dom.ScrollBehavior.auto_ }
		.instant { dom.ScrollBehavior.instant }
		.smooth { dom.ScrollBehavior.smooth }
	}
	native_options := dom.ScrollToOptions_{left: options.left, top: options.top, behavior: behavior}
	native := if name == 'scrollBy' {
		element.scroll_by_with_options(native_options)
	} else {
		element.el_scroll_with_options(native_options)
	}
	host.changed()
	return host.wrap_scroll_promise(mut vm, native)
}

fn (mut host Host) install_element_scrolling() {
	mut prototype := host.element_prototype
	for name in ['scrollLeft', 'scrollTop'] {
		host.accessor(mut prototype, name, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			element := host.element(mut vm)!
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			return libjs.Value.from_f64(if name == 'scrollLeft' { element.scroll_left() } else { element.scroll_top() })
		}, fn [host, name] (mut vm libjs.VM) !libjs.Value {
			mut element := host.element(mut vm)!
			value := vm.argument(0).to_number(mut vm)!.number
			persistent := platform.enter_persistent()
			defer { platform.leave_persistent(persistent) }
			if name == 'scrollLeft' {
				element.set_scroll_left(value)
			} else {
				element.set_scroll_top(value)
			}
			mut owner := unsafe { &Host(host) }
			owner.changed()
			return libjs.js_undefined()
		})
	}
	host.install_scroll_methods(mut prototype, false)
}
