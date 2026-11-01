module css

import dom

fn test_root_face_completion_retains_an_unaffected_descendants_original_cascade() {
	$if macos {
		mut document, root, subject, unrelated := font_input_fixture()
		defer { document.finalize() }
		unaffected := font_input_style(unrelated, none)
		original := unaffected.cached_computed_font_list()?
		selected := font_input_style(subject, none).cached_computed_font_list()?
		font_input_install_real_face(document)
		assert unrelated.has_pending_font_input_update()
		document.update_style()
		assert voidptr(font_input_style(unrelated, none).cached_computed_font_list()?) == voidptr(original)
		assert voidptr(font_input_style(subject, none).cached_computed_font_list()?) != voidptr(selected)
		for element in [root, subject, unrelated] {
			font_input_assert_full_cascade_oracle(element, none)
		}
	}
}

fn test_a_font_only_refresh_keeps_geometry_when_its_settled_font_and_root_metrics_stay_live() {
	$if macos {
		mut document, _, _, unrelated := font_input_fixture()
		defer { document.finalize() }
		style := font_input_style(unrelated, none)
		original := style.cached_computed_font_list()?
		cache := style.computed_layout_cache()
		mut font_computer := css_style_computer_for(document).font_computer()
		font_computer.did_load_font('RefreshUnrelatedFamily')
		mut element := unsafe { &dom.Element(unrelated) }
		element.set_pending_font_input_update(true)
		document.update_style()
		assert !element.has_pending_font_input_update()
		_ = resolve_computed_values_for_document(style, document)
		assert voidptr(style.cached_computed_font_list()?) == voidptr(original)
		assert voidptr(style.computed_layout_cache()) == voidptr(cache)
		font_input_assert_full_cascade_oracle(unrelated, none)
	}
}

fn test_font_only_refresh_replaces_a_cascade_expired_by_its_selected_family() {
	$if macos {
		mut document, _, _, unrelated := font_input_fixture()
		defer { document.finalize() }
		style := font_input_style(unrelated, none)
		original := style.cached_computed_font_list()?
		cache := style.computed_layout_cache()
		mut font_computer := css_style_computer_for(document).font_computer()
		font_computer.did_load_font('serif')
		mut element := unsafe { &dom.Element(unrelated) }
		element.set_pending_font_input_update(true)
		document.update_style()
		_ = resolve_computed_values_for_document(style, document)
		assert voidptr(style.cached_computed_font_list()?) != voidptr(original)
		assert voidptr(style.computed_layout_cache()) != voidptr(cache)
		font_input_assert_full_cascade_oracle(unrelated, none)
	}
}
