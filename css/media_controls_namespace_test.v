module css

import dom

fn test_html_audio_visibility_uses_only_null_namespace_controls_even_with_author_display() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	computer := StyleComputer.new(document)
	for author_style in ['', 'display: block', 'display: inline'] {
		mut audio := document.create_element_ns(dom.namespace_html_uri, 'audio') or { panic(err) }
		audio.set_attribute_value('style', author_style)
		audio.set_attribute_ns_for_bindings('urn:media-controls', 'controls', 'foreign raw') or { panic(err) }
		audio.set_attribute_ns_for_bindings('urn:prefixed-controls', 'mcn:controls', 'prefixed raw') or { panic(err) }
		assert audio.has_attribute('controls') && !audio.has_attribute_ns(none, 'controls')
		hidden := computer.compute_style(dom.AbstractElement.new(audio, none))
		assert hidden.display() == Display.from_short(.none_)
		assert audio.get_attribute_ns('urn:media-controls', 'controls') or { '' } == 'foreign raw'
		assert audio.get_attribute_ns('urn:prefixed-controls', 'controls') or { '' } == 'prefixed raw'

		audio.set_attribute_value('controls', '')
		visible := computer.compute_style(dom.AbstractElement.new(audio, none))
		expected := if author_style == 'display: block' {
			Display.from_short(.block)
		} else {
			Display.from_short(.inline_block)
		}
		assert visible.display() == expected
		assert audio.get_attribute_ns(none, 'controls') or { 'missing' } == ''
		assert audio.get_attribute_ns('urn:media-controls', 'controls') or { '' } == 'foreign raw'
		// Exercise the public adjustment entry point independently of its dispatch guard.
		mut directly_adjusted := computer.compute_style(dom.AbstractElement.new(audio, none))
		assert directly_adjusted.display() == expected
		audio.remove_attribute_ns(none, 'controls')
		html_audio_element_adjust_computed_style(mut directly_adjusted, unsafe { &dom.HTMLAudioElement(audio) })
		assert directly_adjusted.display() == Display.from_short(.none_)
		hidden_again := computer.compute_style(dom.AbstractElement.new(audio, none))
		assert hidden_again.display() == Display.from_short(.none_)
		assert !audio.has_attribute_ns(none, 'controls') && audio.has_attribute('controls')
		assert audio.get_attribute_ns('urn:media-controls', 'controls') or { '' } == 'foreign raw'
		assert audio.get_attribute_ns('urn:prefixed-controls', 'controls') or { '' } == 'prefixed raw'
	}
}

fn test_foreign_audio_elements_keep_author_display_and_namespaced_controls_attributes() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	computer := StyleComputer.new(document)
	for namespace_uri in ['http://www.w3.org/2000/svg', 'http://www.w3.org/1998/Math/MathML'] {
		mut audio := document.create_element_ns(namespace_uri, 'audio') or { panic(err) }
		audio.set_attribute_value('style', 'display: block')
		assert !audio.is_html_element()
		without_controls := computer.compute_style(dom.AbstractElement.new(audio, none))
		assert without_controls.display() == Display.from_short(.block)
		audio.set_attribute_ns_for_bindings('urn:media-controls', 'controls', 'foreign raw') or { panic(err) }
		audio.set_attribute_ns_for_bindings('urn:prefixed-controls', 'mcn:controls', 'prefixed raw') or { panic(err) }
		foreign_controls := computer.compute_style(dom.AbstractElement.new(audio, none))
		assert foreign_controls.display() == Display.from_short(.block)
		assert !audio.has_attribute_ns(none, 'controls') && audio.has_attribute('controls')
		audio.set_attribute_value('controls', 'ordinary attribute')
		with_controls := computer.compute_style(dom.AbstractElement.new(audio, none))
		assert with_controls.display() == Display.from_short(.block)
		audio.remove_attribute_ns(none, 'controls')
		after_removal := computer.compute_style(dom.AbstractElement.new(audio, none))
		assert after_removal.display() == Display.from_short(.block)
		assert !audio.has_attribute_ns(none, 'controls')
		assert audio.get_attribute_ns('urn:media-controls', 'controls') or { '' } == 'foreign raw'
		assert audio.get_attribute_ns('urn:prefixed-controls', 'controls') or { '' } == 'prefixed raw'
		assert audio.namespace_uri() or { '' } == namespace_uri
	}
}
