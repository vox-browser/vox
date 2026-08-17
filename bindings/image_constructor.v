// Copyright (c) 2021-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/ImageConstructor.{h,cpp}.
module bindings

import dom
import math

@[heap]
pub struct ImageConstructor {
pub:
	document &dom.Document
}

pub fn ImageConstructor.create(document &dom.Document) &ImageConstructor {
	return &ImageConstructor{
		document: document
	}
}

pub fn (_ &ImageConstructor) metadata() ConstructorMetadata {
	return ConstructorMetadata{
		name:           'Image'
		length:         0
		prototype_name: 'HTMLImageElement'
	}
}

pub fn (_ &ImageConstructor) call() !dom.JSValue {
	return error("TypeError: Constructor Image requires 'new'")
}

fn js_value_to_number(value dom.JSValue) f64 {
	return match value.kind {
		.undefined {
			math.nan()
		}
		.null_ {
			0.0
		}
		.boolean {
			if value.boolean_data {
				1.0
			} else {
				0.0
			}
		}
		.number {
			value.number_data
		}
		.string {
			value.string_data.trim_space().f64()
		}
		.object {
			math.nan()
		}
	}
}

// ECMAScript ToUint32, used by the Image(width, height) constructor.
fn js_value_to_u32(value dom.JSValue) u32 {
	number := js_value_to_number(value)
	if math.is_nan(number) || math.is_inf(number, 0) || number == 0 {
		return 0
	}
	integer := if number < 0 { math.ceil(number) } else { math.floor(number) }
	mut modulo := math.fmod(integer, 4294967296.0)
	if modulo < 0 {
		modulo += 4294967296.0
	}
	return u32(modulo)
}

// https://html.spec.whatwg.org/multipage/embedded-content.html#dom-image
pub fn (constructor &ImageConstructor) construct(width ?dom.JSValue, height ?dom.JSValue) !&dom.HTMLImageElement {
	mut element := dom.create_element(constructor.document, 'img', html_namespace, none, none,
		false)!
	if width_value := width {
		element.set_attribute_value('width', js_value_to_u32(width_value).str())
	}
	if height_value := height {
		element.set_attribute_value('height', js_value_to_u32(height_value).str())
	}
	return unsafe { &dom.HTMLImageElement(element) }
}
