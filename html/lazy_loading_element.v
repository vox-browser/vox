// Copyright (c) 2026, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of the header-only LazyLoadingElement template. V represents
// the including element explicitly while retaining the one-shot resumption
// callback semantics.
module html

import dom

pub enum LazyLoading {
	lazy
	eager
}

@[heap]
pub struct LazyLoadingElement {
pub:
	element &dom.Element
mut:
	lazy_load_resumption_steps_ ?fn ()
}

pub fn LazyLoadingElement.create(element &dom.Element) &LazyLoadingElement {
	return &LazyLoadingElement{element: element}
}

pub fn (element &LazyLoadingElement) lazy_loading_attribute() LazyLoading {
	return if element.element.get_attribute_value('loading').to_lower() == 'lazy' {
		.lazy
	} else {
		.eager
	}
}

pub fn (element &LazyLoadingElement) will_lazy_load_element() bool {
	return element.element.as_node().is_scripting_enabled()
		&& element.lazy_loading_attribute() == .lazy
}

pub fn (mut element LazyLoadingElement) set_lazy_load_resumption_steps(steps fn ()) {
	element.lazy_load_resumption_steps_ = steps
}

pub fn (element &LazyLoadingElement) visit_lazy_loading_element(mut visitor dom.CellVisitor) {
	visitor.visit(voidptr(element))
}

pub fn (mut element LazyLoadingElement) take_lazy_load_resumption_steps_internal() ?fn () {
	steps := element.lazy_load_resumption_steps_
	element.lazy_load_resumption_steps_ = none
	return steps
}
