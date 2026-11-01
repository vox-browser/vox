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

fn live_pending_refresh_fixture() (&dom.Document, &dom.Element, &FontFaceObject) {
	mut document, _, _, mut element := font_input_fixture()
	computer := css_style_computer_for(document).font_computer()
	mut face := FontFaceObject.construct_impl_for_font_computer(computer,
		'RefreshPending', FontFaceSource.from_string('url("pending.ttf")'),
		FontFaceDescriptors{display: 'fallback'})
	mut set := FontFaceSet.create_for_font_computer(computer)
	set.add(face) or { panic(err) }
	// Keep transport pending; advance the real display-state boundary explicitly.
	face.status_ = .loading
	face.set_font_display_time_for_testing(0)
	element.set_attribute_value('style', 'font-family:RefreshPending,serif;font-size:20px;width:120px')
	document.update_style()
	style := font_input_style(element, none)
	_ = resolve_computed_values_for_document(style, document)
	list := style.cached_computed_font_list() or { panic('missing cascade') }
	assert list.pending_faces.len == 1
	assert list.font_for_code_point_for_shaping(`A`).is_invisible
	// Inspect the invalidation before ready-promise settlement can consume it
	// through its synchronous layout flush.
	set.set_is_pending_on_the_environment(true)
	return document, element, face
}

fn test_font_only_refresh_keeps_original_live_pending_metrics_and_visibility() {
	$if macos {
		mut document, element, _ := live_pending_refresh_fixture()
		defer { document.finalize() }
		computer := css_style_computer_for(document)
		style := font_input_style(element, none)
		list := style.cached_computed_font_list()?
		cache := style.computed_layout_cache()
		line_height := style.computed_values_line_height_
		metrics := list.font_for_code_point(`A`).font_for_metrics().inline_metrics()
		mut fonts := computer.font_computer()
		fonts.did_load_font('UnrelatedRefreshPending')
		subject := dom.AbstractElement.new(element, none)
		assert computer.can_refresh_font_inputs(subject)
		invalidation := computer.refresh_font_inputs(subject)
		assert invalidation.is_none() == !disable_live_pending_font_refresh
		assert voidptr(style.cached_computed_font_list()?) == voidptr(list)
		assert style.computed_values_line_height_ == line_height
		assert list.font_for_code_point(`A`).font_for_metrics().inline_metrics() == metrics
		assert list.font_for_code_point_for_shaping(`A`).is_invisible
		if !disable_live_pending_font_refresh {
			assert voidptr(style.computed_layout_cache()) == voidptr(cache)
		}
	}
}

fn test_font_only_refresh_invalidates_pending_block_to_swap_visibility() {
	$if macos {
		mut document, element, mut face := live_pending_refresh_fixture()
		defer { document.finalize() }
		computer := css_style_computer_for(document)
		mut style := font_input_style(element, none)
		list := style.cached_computed_font_list()?
		face.set_font_display_time_for_testing(100)
		_ = style.computed_font_list(computer.font_computer())
		invalidation := computer.refresh_font_inputs(dom.AbstractElement.new(element, none))
		assert !invalidation.is_none()
		replacement := style.cached_computed_font_list()?
		assert voidptr(replacement) != voidptr(list)
		assert replacement.pending_faces.len == 1
		assert !replacement.font_for_code_point_for_shaping(`A`).is_invisible
	}
}

fn test_font_only_refresh_invalidates_pending_download_failure() {
	$if macos {
		mut document, element, mut face := live_pending_refresh_fixture()
		defer { document.finalize() }
		computer := css_style_computer_for(document)
		mut style := font_input_style(element, none)
		list := style.cached_computed_font_list()?
		face.finish_loading_from_typeface(unsafe { nil })
		_ = style.computed_font_list(computer.font_computer())
		invalidation := computer.refresh_font_inputs(dom.AbstractElement.new(element, none))
		assert !invalidation.is_none()
		replacement := style.cached_computed_font_list()?
		assert voidptr(replacement) != voidptr(list)
		assert replacement.pending_faces.len == 0
		assert !replacement.font_for_code_point_for_shaping(`A`).is_invisible
	}
}

fn test_font_only_refresh_preserves_original_geometry_inputs_after_a_selected_font_query() {
	$if macos {
		mut document, element, mut face := live_pending_refresh_fixture()
		defer { document.finalize() }
		computer := css_style_computer_for(document)
		mut style := font_input_style(element, none)
		original := style.cached_computed_font_list()?
		typeface := platform_load_font_from_url_boundary('file:///System/Library/Fonts/Supplemental/Arial.ttf', 'RefreshPending')
		assert typeface != unsafe { nil }
		face.finish_loading_from_typeface(typeface)
		replacement := style.computed_font_list(computer.font_computer())
		assert voidptr(replacement) != voidptr(original)
		assert replacement.pending_faces.len == 0
		assert voidptr(style.font_input_refresh_snapshot_) == voidptr(original)
		invalidation := computer.refresh_font_inputs(dom.AbstractElement.new(element, none))
		assert !invalidation.is_none()
		assert voidptr(style.font_input_refresh_snapshot_) == voidptr(replacement)
	}
}
