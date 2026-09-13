module dom

fn test_svg_animation_element_event_handler_attributes_follow_upstream_keys() {
	document := Document.create(url_about_blank())
	element := &SVGAnimationElement{
		SVGElement: new_svg_element_storage(document, QualifiedName{
			local_name: 'animate'
			namespace_: namespace_svg_uri
		})
	}
	begin_handler := &CallbackType{}
	end_handler := &CallbackType{}
	repeat_handler := &CallbackType{}

	element.set_onbegin(begin_handler)
	assert element.onbegin()? == begin_handler

	// These intentionally preserve the current upstream key choices: onend()
	// reads "error", while set_onrepeat() writes "end".
	element.set_onend(end_handler)
	assert element.onend() == none
	assert unsafe { &EventTarget(element) }.event_handler_attribute('end')? == end_handler
	element.set_onrepeat(repeat_handler)
	assert unsafe { &EventTarget(element) }.event_handler_attribute('end')? == repeat_handler
	assert element.onrepeat() == none

	unsafe { &EventTarget(element) }.set_event_handler_attribute('error', end_handler)
	unsafe { &EventTarget(element) }.set_event_handler_attribute('repeat', repeat_handler)
	assert element.onend()? == end_handler
	assert element.onrepeat()? == repeat_handler
}
