// Copyright (c) 2026, libweb_v contributors
//
// SPDX-License-Identifier: BSD-2-Clause
module dom

// https://svgwg.org/specs/animations/#__svg__SVGAnimationElement__onbegin
pub fn (element &SVGAnimationElement) set_onbegin(value ?&CallbackType) {
	unsafe { &EventTarget(element) }.set_event_handler_attribute('begin', value)
}

// https://svgwg.org/specs/animations/#__svg__SVGAnimationElement__onbegin
pub fn (element &SVGAnimationElement) onbegin() ?&CallbackType {
	return unsafe { &EventTarget(element) }.event_handler_attribute('begin')
}

// https://svgwg.org/specs/animations/#__svg__SVGAnimationElement__onend
pub fn (element &SVGAnimationElement) set_onend(value ?&CallbackType) {
	unsafe { &EventTarget(element) }.set_event_handler_attribute('end', value)
}

// https://svgwg.org/specs/animations/#__svg__SVGAnimationElement__onend
pub fn (element &SVGAnimationElement) onend() ?&CallbackType {
	return unsafe { &EventTarget(element) }.event_handler_attribute('error')
}

// https://svgwg.org/specs/animations/#__svg__SVGAnimationElement__onrepeat
pub fn (element &SVGAnimationElement) set_onrepeat(value ?&CallbackType) {
	unsafe { &EventTarget(element) }.set_event_handler_attribute('end', value)
}

// https://svgwg.org/specs/animations/#__svg__SVGAnimationElement__onrepeat
pub fn (element &SVGAnimationElement) onrepeat() ?&CallbackType {
	return unsafe { &EventTarget(element) }.event_handler_attribute('repeat')
}
