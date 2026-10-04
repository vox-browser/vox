// Exact pinned GlobalEventHandlers.h / WindowEventHandlers.h macro expansions.
module dom

fn event_name_from_event_handler_attribute_local_name(local_name string) ?string {
	return match local_name {
		'onabort' { 'abort' }
		'onanimationcancel' { 'animationcancel' }
		'onanimationend' { 'animationend' }
		'onanimationiteration' { 'animationiteration' }
		'onanimationstart' { 'animationstart' }
		'onauxclick' { 'auxclick' }
		'onbeforeinput' { 'beforeinput' }
		'onbeforematch' { 'beforematch' }
		'onbeforetoggle' { 'beforetoggle' }
		'onblur' { 'blur' }
		'oncancel' { 'cancel' }
		'oncanplay' { 'canplay' }
		'oncanplaythrough' { 'canplaythrough' }
		'onchange' { 'change' }
		'onclick' { 'click' }
		'onclose' { 'close' }
		'oncommand' { 'command' }
		'oncontextlost' { 'contextlost' }
		'oncontextmenu' { 'contextmenu' }
		'oncontextrestored' { 'contextrestored' }
		'oncopy' { 'copy' }
		'oncuechange' { 'cuechange' }
		'oncut' { 'cut' }
		'ondblclick' { 'dblclick' }
		'ondrag' { 'drag' }
		'ondragend' { 'dragend' }
		'ondragenter' { 'dragenter' }
		'ondragleave' { 'dragleave' }
		'ondragover' { 'dragover' }
		'ondragstart' { 'dragstart' }
		'ondrop' { 'drop' }
		'ondurationchange' { 'durationchange' }
		'onemptied' { 'emptied' }
		'onended' { 'ended' }
		'onerror' { 'error' }
		'onfocus' { 'focus' }
		'onfocusin' { 'focusin' }
		'onfocusout' { 'focusout' }
		'onformdata' { 'formdata' }
		'ongotpointercapture' { 'gotpointercapture' }
		'oninput' { 'input' }
		'oninvalid' { 'invalid' }
		'onkeydown' { 'keydown' }
		'onkeypress' { 'keypress' }
		'onkeyup' { 'keyup' }
		'onload' { 'load' }
		'onloadeddata' { 'loadeddata' }
		'onloadedmetadata' { 'loadedmetadata' }
		'onloadstart' { 'loadstart' }
		'onlostpointercapture' { 'lostpointercapture' }
		'onmousedown' { 'mousedown' }
		'onmouseenter' { 'mouseenter' }
		'onmouseleave' { 'mouseleave' }
		'onmousemove' { 'mousemove' }
		'onmouseout' { 'mouseout' }
		'onmouseover' { 'mouseover' }
		'onmouseup' { 'mouseup' }
		'onpaste' { 'paste' }
		'onpause' { 'pause' }
		'onplay' { 'play' }
		'onplaying' { 'playing' }
		'onpointercancel' { 'pointercancel' }
		'onpointerdown' { 'pointerdown' }
		'onpointerenter' { 'pointerenter' }
		'onpointerleave' { 'pointerleave' }
		'onpointermove' { 'pointermove' }
		'onpointerout' { 'pointerout' }
		'onpointerover' { 'pointerover' }
		'onpointerrawupdate' { 'pointerrawupdate' }
		'onpointerup' { 'pointerup' }
		'onprogress' { 'progress' }
		'onratechange' { 'ratechange' }
		'onreset' { 'reset' }
		'onresize' { 'resize' }
		'onscroll' { 'scroll' }
		'onscrollend' { 'scrollend' }
		'onsecuritypolicyviolation' { 'securitypolicyviolation' }
		'onseeked' { 'seeked' }
		'onseeking' { 'seeking' }
		'onselect' { 'select' }
		'onselectionchange' { 'selectionchange' }
		'onslotchange' { 'slotchange' }
		'onstalled' { 'stalled' }
		'onsubmit' { 'submit' }
		'onsuspend' { 'suspend' }
		'ontimeupdate' { 'timeupdate' }
		'ontoggle' { 'toggle' }
		'ontransitioncancel' { 'transitioncancel' }
		'ontransitionend' { 'transitionend' }
		'ontransitionrun' { 'transitionrun' }
		'ontransitionstart' { 'transitionstart' }
		'onvolumechange' { 'volumechange' }
		'onwaiting' { 'waiting' }
		'onwebkitanimationend' { 'webkitAnimationEnd' }
		'onwebkitanimationiteration' { 'webkitAnimationIteration' }
		'onwebkitanimationstart' { 'webkitAnimationStart' }
		'onwebkittransitionend' { 'webkitTransitionEnd' }
		'onwheel' { 'wheel' }
		'onafterprint' { 'afterprint' }
		'onbeforeprint' { 'beforeprint' }
		'onbeforeunload' { 'beforeunload' }
		'ongamepadconnected' { 'gamepadconnected' }
		'ongamepaddisconnected' { 'gamepaddisconnected' }
		'onhashchange' { 'hashchange' }
		'onlanguagechange' { 'languagechange' }
		'onmessage' { 'message' }
		'onmessageerror' { 'messageerror' }
		'onoffline' { 'offline' }
		'ononline' { 'online' }
		'onpagehide' { 'pagehide' }
		'onpagereveal' { 'pagereveal' }
		'onpageshow' { 'pageshow' }
		'onpageswap' { 'pageswap' }
		'onpopstate' { 'popstate' }
		'onrejectionhandled' { 'rejectionhandled' }
		'onstorage' { 'storage' }
		'onunhandledrejection' { 'unhandledrejection' }
		'onunload' { 'unload' }
		else { none }
	}
}

fn is_global_event_handler_content_attribute(local_name string) bool {
	return match local_name {
		'onabort', 'onanimationcancel', 'onanimationend', 'onanimationiteration', 'onanimationstart',
		'onauxclick', 'onbeforeinput', 'onbeforematch', 'onbeforetoggle', 'onblur', 'oncancel',
		'oncanplay', 'oncanplaythrough', 'onchange', 'onclick', 'onclose', 'oncommand',
		'oncontextlost', 'oncontextmenu', 'oncontextrestored', 'oncopy', 'oncuechange', 'oncut',
		'ondblclick', 'ondrag', 'ondragend', 'ondragenter', 'ondragleave', 'ondragover',
		'ondragstart', 'ondrop', 'ondurationchange', 'onemptied', 'onended', 'onerror', 'onfocus',
		'onfocusin', 'onfocusout', 'onformdata', 'ongotpointercapture', 'oninput', 'oninvalid',
		'onkeydown', 'onkeypress', 'onkeyup', 'onload', 'onloadeddata', 'onloadedmetadata',
		'onloadstart', 'onlostpointercapture', 'onmousedown', 'onmouseenter', 'onmouseleave',
		'onmousemove', 'onmouseout', 'onmouseover', 'onmouseup', 'onpaste', 'onpause', 'onplay',
		'onplaying', 'onpointercancel', 'onpointerdown', 'onpointerenter', 'onpointerleave',
		'onpointermove', 'onpointerout', 'onpointerover', 'onpointerrawupdate', 'onpointerup',
		'onprogress', 'onratechange', 'onreset', 'onresize', 'onscroll', 'onscrollend',
		'onsecuritypolicyviolation', 'onseeked', 'onseeking', 'onselect', 'onselectionchange',
		'onslotchange', 'onstalled', 'onsubmit', 'onsuspend', 'ontimeupdate', 'ontoggle',
		'ontransitioncancel', 'ontransitionend', 'ontransitionrun', 'ontransitionstart',
		'onvolumechange', 'onwaiting', 'onwebkitanimationend', 'onwebkitanimationiteration',
		'onwebkitanimationstart', 'onwebkittransitionend', 'onwheel' {
			true
		}
		else { false }
	}
}

fn is_window_event_handler_content_attribute(local_name string) bool {
	return match local_name {
		'onafterprint', 'onbeforeprint', 'onbeforeunload', 'ongamepadconnected',
		'ongamepaddisconnected', 'onhashchange', 'onlanguagechange', 'onmessage', 'onmessageerror',
		'onoffline', 'ononline', 'onpagehide', 'onpagereveal', 'onpageshow', 'onpageswap',
		'onpopstate', 'onrejectionhandled', 'onstorage', 'onunhandledrejection', 'onunload' {
			true
		}
		else { false }
	}
}
