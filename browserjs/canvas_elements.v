// Retain native canvas element identity across the compact DOM replay pass.
module browserjs

import dom

pub type CanvasElementProvider = fn () map[string]&dom.Element

pub fn (mut runtime Runtime) add_canvas_element_provider(provider CanvasElementProvider) {
	runtime.canvas_element_providers_ << provider
}

pub fn (runtime &Runtime) canvas_elements_for_binding() map[string]&dom.Element {
	mut elements := map[string]&dom.Element{}
	for provider in runtime.canvas_element_providers_ {
		for key, element in provider() {
			elements[key] = element
		}
	}
	return elements
}
