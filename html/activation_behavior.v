// Copyright (c) 2026-present, the Ladybird developers
// SPDX-License-Identifier: BSD-2-Clause

// The has_activation_behavior(), activation_behavior(), and legacy activation overrides of HTMLButtonElement,
// HTMLInputElement, HTMLLabelElement, HTMLSelectElement, and HTMLSummaryElement. DOM's event dispatch reaches these
// virtual EventTarget overrides through the hooks installed here.
module html

import dom

fn html_activation_element_kind(element &dom.Element) string {
	if !element.is_html_element() {
		return ''
	}
	return element.local_name()
}

fn html_element_has_activation_behavior(element &dom.Element) bool {
	return match html_activation_element_kind(element) {
		'button' {
			HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(element) }).has_activation_behavior()
		}
		'input' {
			HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) }).has_activation_behavior()
		}
		'label' {
			html_label_element_has_activation_behavior(unsafe { &dom.HTMLLabelElement(element) })
		}
		'select' {
			HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(element) }).has_activation_behavior()
		}
		'summary' {
			html_summary_element_has_activation_behavior(unsafe { &dom.HTMLSummaryElement(element) })
		}
		else {
			false
		}
	}
}

fn html_element_activation_behavior(element &dom.Element, event &dom.Event) {
	match html_activation_element_kind(element) {
		'button' {
			mut model := HTMLButtonElementModel.create(unsafe { &dom.HTMLButtonElement(element) })
			model.activation_behavior(event)
		}
		'input' {
			mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
			model.activation_behavior(event) or {}
		}
		'label' {
			html_label_element_activation_behavior(unsafe { &dom.HTMLLabelElement(element) }, event)
		}
		'select' {
			mut model := HTMLSelectElementModel.create(unsafe { &dom.HTMLSelectElement(element) })
			model.activation_behavior(event)
		}
		'summary' {
			html_summary_element_activation_behavior(unsafe { &dom.HTMLSummaryElement(element) })
		}
		else {}
	}
}

// NOTE: The legacy activation behaviors only exist for checkbox and radio input elements.
fn html_element_legacy_pre_activation_behavior(element &dom.Element) {
	if html_activation_element_kind(element) == 'input' {
		mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		model.legacy_pre_activation_behavior()
	}
}

fn html_element_legacy_cancelled_activation_behavior(element &dom.Element) {
	if html_activation_element_kind(element) == 'input' {
		mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		model.legacy_cancelled_activation_behavior()
	}
}

fn html_element_legacy_cancelled_activation_behavior_was_not_called(element &dom.Element) {
	if html_activation_element_kind(element) == 'input' {
		mut model := HTMLInputElementModel.create(unsafe { &dom.HTMLInputElement(element) })
		model.legacy_cancelled_activation_behavior_was_not_called()
	}
}

fn install_html_element_activation_behavior() {
	dom.install_element_activation_behavior_hooks(dom.ElementActivationBehaviorHooks{
		has_activation_behavior: html_element_has_activation_behavior
		activation_behavior: html_element_activation_behavior
		legacy_pre_activation_behavior: html_element_legacy_pre_activation_behavior
		legacy_cancelled_activation_behavior: html_element_legacy_cancelled_activation_behavior
		legacy_cancelled_activation_behavior_was_not_called: html_element_legacy_cancelled_activation_behavior_was_not_called
	})
}
