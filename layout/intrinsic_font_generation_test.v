module layout

import css
import html

fn test_late_web_font_remeasures_a_shrink_to_fit_buttons_intrinsic_width() {
	$if macos {
		mut document := html.parse_document('<!doctype html><style>button{display:block;margin-left:auto;border:0;padding:0;font:20px/24px LateIntrinsicFace,monospace}</style><button id="subject">iiiiiiii</button>')
		defer { document.finalize() }
		_ = layout_document_typed_in_viewport(document, 400, 200)
		element := document.get_element_by_id('subject') or { panic('missing button') }
		initial := element.get_bounding_client_rect()
		mut face := css.FontFaceObject.construct_impl('LateIntrinsicFace', css.FontFaceSource.from_string("url('file:///System/Library/Fonts/Supplemental/Arial.ttf')"), css.FontFaceDescriptors{})
		mut computer := css.css_style_computer_for(document)
		mut fonts := computer.font_face_set_
		fonts.add(face) or { panic(err) }
		face.load()
		assert face.status() == .loaded
		document.update_layout(.debugging)
		loaded := element.get_bounding_client_rect()
		assert loaded.width < initial.width * 0.8
		document.set_needs_full_layout_tree_update(true)
		document.update_layout(.debugging)
		fresh := element.get_bounding_client_rect()
		assert loaded.width == fresh.width && loaded.x == fresh.x
	}
}
