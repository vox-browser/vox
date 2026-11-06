module browserjs

// Platform input and hover already dispatch these events through the DOM.
// Compact Element and Document listeners must join that same listener list.
pub fn native_pointer_event_names() []string {
	return ['auxclick', 'click', 'contextmenu', 'dblclick', 'mousedown', 'mouseenter', 'mouseleave',
		'mousemove', 'mouseout', 'mouseover', 'mouseup', 'pointercancel', 'pointerdown', 'pointerenter',
		'pointerleave', 'pointermove', 'pointerout', 'pointerover', 'pointerrawupdate', 'pointerup',
		'gotpointercapture', 'lostpointercapture']
}
