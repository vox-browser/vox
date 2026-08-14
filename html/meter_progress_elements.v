// Copyright (c) 2020-2023, Ladybird contributors
//
// SPDX-License-Identifier: BSD-2-Clause

// Translation of HTMLProgressElement.cpp and HTMLMeterElement.cpp.
module html

import dom

fn clamp_html_number(value f64, minimum f64, maximum f64) f64 {
	if value < minimum {
		return minimum
	}
	if value > maximum {
		return maximum
	}
	return value
}

fn progress_element_as_dom_element(element &dom.HTMLProgressElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

// https://html.spec.whatwg.org/multipage/form-elements.html#dom-progress-value
pub fn html_progress_element_value(element &dom.HTMLProgressElement) f64 {
	dom_element := progress_element_as_dom_element(element)
	if value_string := dom_element.get_attribute('value') {
		if value := parse_floating_point_number(value_string) {
			return clamp_html_number(value, 0, html_progress_element_max(element))
		}
	}
	return 0
}

pub fn set_html_progress_element_value(element &dom.HTMLProgressElement, value f64) {
	mut normalized_value := value
	if normalized_value < 0 {
		normalized_value = 0
	}
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('value', normalized_value.str())
}

// https://html.spec.whatwg.org/multipage/form-elements.html#dom-progress-max
pub fn html_progress_element_max(element &dom.HTMLProgressElement) f64 {
	dom_element := progress_element_as_dom_element(element)
	if max_string := dom_element.get_attribute('max') {
		if maximum := parse_floating_point_number(max_string) {
			if maximum > 0 {
				return maximum
			}
		}
	}
	return 1
}

pub fn set_html_progress_element_max(element &dom.HTMLProgressElement, value f64) {
	if value <= 0 {
		return
	}
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('max', value.str())
}

pub fn html_progress_element_position(element &dom.HTMLProgressElement) f64 {
	if !progress_element_as_dom_element(element).has_attribute('value') {
		return -1
	}
	return html_progress_element_value(element) / html_progress_element_max(element)
}

fn meter_element_as_dom_element(element &dom.HTMLMeterElement) &dom.Element {
	return unsafe { &dom.Element(element) }
}

// https://html.spec.whatwg.org/multipage/form-elements.html#concept-meter-actual
pub fn html_meter_element_value(element &dom.HTMLMeterElement) f64 {
	dom_element := meter_element_as_dom_element(element)
	mut candidate_value := 0.0
	if value_string := dom_element.get_attribute('value') {
		if value := parse_floating_point_number(value_string) {
			candidate_value = value
		}
	}
	return clamp_html_number(candidate_value, html_meter_element_min(element),
		html_meter_element_max(element))
}

pub fn set_html_meter_element_value(element &dom.HTMLMeterElement, value f64) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('value', value.str())
}

// https://html.spec.whatwg.org/multipage/form-elements.html#concept-meter-minimum
pub fn html_meter_element_min(element &dom.HTMLMeterElement) f64 {
	if min_string := meter_element_as_dom_element(element).get_attribute('min') {
		if minimum := parse_floating_point_number(min_string) {
			return minimum
		}
	}
	return 0
}

pub fn set_html_meter_element_min(element &dom.HTMLMeterElement, value f64) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('min', value.str())
}

// https://html.spec.whatwg.org/multipage/form-elements.html#concept-meter-maximum
pub fn html_meter_element_max(element &dom.HTMLMeterElement) f64 {
	dom_element := meter_element_as_dom_element(element)
	mut candidate_max := 1.0
	if max_string := dom_element.get_attribute('max') {
		if maximum := parse_floating_point_number(max_string) {
			candidate_max = maximum
		}
	}
	minimum := html_meter_element_min(element)
	return if candidate_max > minimum { candidate_max } else { minimum }
}

pub fn set_html_meter_element_max(element &dom.HTMLMeterElement, value f64) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('max', value.str())
}

// https://html.spec.whatwg.org/multipage/form-elements.html#concept-meter-low
pub fn html_meter_element_low(element &dom.HTMLMeterElement) f64 {
	dom_element := meter_element_as_dom_element(element)
	minimum := html_meter_element_min(element)
	mut candidate_low := minimum
	if low_string := dom_element.get_attribute('low') {
		if low := parse_floating_point_number(low_string) {
			candidate_low = low
		}
	}
	return clamp_html_number(candidate_low, minimum, html_meter_element_max(element))
}

pub fn set_html_meter_element_low(element &dom.HTMLMeterElement, value f64) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('low', value.str())
}

// https://html.spec.whatwg.org/multipage/form-elements.html#concept-meter-high
pub fn html_meter_element_high(element &dom.HTMLMeterElement) f64 {
	dom_element := meter_element_as_dom_element(element)
	maximum := html_meter_element_max(element)
	mut candidate_high := maximum
	if high_string := dom_element.get_attribute('high') {
		if high := parse_floating_point_number(high_string) {
			candidate_high = high
		}
	}
	return clamp_html_number(candidate_high, html_meter_element_low(element), maximum)
}

pub fn set_html_meter_element_high(element &dom.HTMLMeterElement, value f64) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('high', value.str())
}

// https://html.spec.whatwg.org/multipage/form-elements.html#concept-meter-optimum
pub fn html_meter_element_optimum(element &dom.HTMLMeterElement) f64 {
	minimum := html_meter_element_min(element)
	maximum := html_meter_element_max(element)
	mut candidate_optimum := (maximum + minimum) / 2
	if optimum_string := meter_element_as_dom_element(element).get_attribute('optimum') {
		if optimum := parse_floating_point_number(optimum_string) {
			candidate_optimum = optimum
		}
	}
	return clamp_html_number(candidate_optimum, minimum, maximum)
}

pub fn set_html_meter_element_optimum(element &dom.HTMLMeterElement, value f64) {
	mut dom_element := unsafe { &dom.Element(element) }
	dom_element.set_attribute_value('optimum', value.str())
}

pub enum MeterValueState {
	optimal
	suboptimal
	even_less_good
}

pub fn html_meter_element_value_state(element &dom.HTMLMeterElement) MeterValueState {
	value := html_meter_element_value(element)
	maximum := html_meter_element_max(element)
	low := html_meter_element_low(element)
	high := html_meter_element_high(element)
	optimum := html_meter_element_optimum(element)

	if optimum >= low && optimum <= high {
		return if value >= low && value <= high { .optimal } else { .suboptimal }
	}
	if optimum < low {
		return if value >= low && value <= high { .suboptimal } else { .even_less_good }
	}
	if value >= high && value <= maximum {
		return .optimal
	}
	if value >= low && value <= high {
		return .suboptimal
	}
	return .even_less_good
}
