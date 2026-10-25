module layout

import css
import dom

fn test_text_input_auto_size_tracks_style_and_size_attribute_changes() {
	for policy in [dom.FontRenderingPolicy.libweb, .chromium] {
		mut document := dom.Document.create(dom.url_about_blank())
		defer { document.finalize() }
		document.set_font_rendering_policy(policy)
		mut element := document.create_element_ns('http://www.w3.org/1999/xhtml', 'input')!
		element.set_attribute_value('style', 'font:10px/16px monospace')
		element.set_attribute_value('size', '20')
		computer := css.css_style_computer_for(document)
		initial_style := computer.compute_style(dom.AbstractElement.new(element, none))
		input := TextInputBox.new(document, element, initial_style)
		box := unsafe { &Box(input) }
		initial := box.auto_content_box_size()
		assert initial.height?.to_double() == 16

		// Style refresh preserves this layout box. Its intrinsic dimensions
		// must use the new font and line height rather than construction values.
		element.set_attribute_value('style', 'font:20px/48px monospace')
		mut styled := unsafe { &NodeWithStyle(input) }
		styled.apply_style(computer.compute_style(dom.AbstractElement.new(element, none)))
		updated := box.auto_content_box_size()
		assert updated.height?.to_double() == 48
		assert updated.width?.to_double() > initial.width?.to_double()

		element.set_attribute_value('size', '30')
		more_columns := box.auto_content_box_size()
		assert more_columns.width?.to_double() > updated.width?.to_double()
		assert more_columns.height?.to_double() == 48

		element.set_attribute_value('style', 'font:20px/48px monospace;writing-mode:vertical-rl')
		styled.apply_style(computer.compute_style(dom.AbstractElement.new(element, none)))
		vertical := box.auto_content_box_size()
		assert vertical.width?.to_double() == 48
		assert vertical.height? == more_columns.width?
	}
}
