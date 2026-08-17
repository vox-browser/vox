// Copyright (c) 2022-2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of Bindings/AudioConstructor.{h,cpp}.
module bindings

import dom

const html_namespace = 'http://www.w3.org/1999/xhtml'

pub struct ConstructorMetadata {
pub:
	name           string
	length         int
	prototype_name string
}

@[heap]
pub struct AudioConstructor {
pub:
	document &dom.Document
}

pub fn AudioConstructor.create(document &dom.Document) &AudioConstructor {
	return &AudioConstructor{
		document: document
	}
}

pub fn (_ &AudioConstructor) metadata() ConstructorMetadata {
	return ConstructorMetadata{
		name:           'Audio'
		length:         0
		prototype_name: 'HTMLAudioElement'
	}
}

pub fn (_ &AudioConstructor) call() !dom.JSValue {
	return error("TypeError: Constructor Audio requires 'new'")
}

// https://html.spec.whatwg.org/multipage/media.html#dom-audio
pub fn (constructor &AudioConstructor) construct(src ?dom.JSValue) !&dom.HTMLAudioElement {
	mut element := dom.create_element(constructor.document, 'audio', html_namespace, none, none,
		false)!
	element.set_attribute_value('preload', 'auto')
	if source := src {
		if !source.is_undefined() {
			element.set_attribute_value('src', source.to_string_value())
		}
	}
	return unsafe { &dom.HTMLAudioElement(element) }
}
