module css

import dom
import platform

fn all_media_feature_names() []string {
	mut names := []string{}
	$for value in MediaFeatureID.values {
		names << value.name.replace('_', '-')
	}
	return names
}

fn assert_media_feature_lookup_matches_name_chain(name string, document ?&dom.Document) {
	control := query_media_feature_by_name(name, document)
	actual := query_media_feature(name, document)
	if expected := control {
		value := actual or { panic(name) }
		assert value.kind == expected.kind, name
		assert value.name == expected.name, name
		assert value.text == expected.text, name
		assert value.value == expected.value, name
		assert value.typed_value == none
	} else {
		assert actual == none, name
	}
}

fn test_media_feature_lookup_covers_every_supported_identifier() {
	names := all_media_feature_names()
	assert names.len == 37
	for name in names {
		id := media_feature_id_for_name(name) or { panic(name) }
		assert id.str().replace('_', '-') == name
		assert_media_feature_lookup_matches_name_chain(name, none)
		assert media_feature_id_for_name(name.to_upper()) == none
		assert media_feature_id_for_name(name + 'x') == none
	}
}

fn test_media_feature_lookup_reads_current_viewport_preferences_and_density() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	for width in [0.0, 375.25, 800.5, 1280.0] {
		for height in [0.0, 400.25, 1000.0] {
			document.set_viewport_rect(dom.Rect{0, 0, width, height})
			for density in [1.0, 1.5, 2.0] {
				document.set_display_device_pixel_ratio(density)
				for scheme in ['light', 'dark', 'DARK', 'auto'] {
					document.set_svg_image_color_scheme(scheme)
					for name in all_media_feature_names() {
						assert_media_feature_lookup_matches_name_chain(name, document)
					}
				}
			}
		}
	}
}

fn test_media_feature_lookup_rejects_arbitrary_and_case_sensitive_names() {
	for name in ['', 'WIDTH', 'Width', 'min-width', 'max-height', 'width ', ' width', 'width\x00',
		'wídth', '色', 'prefers-color-schemE', 'x'.repeat(32768)] {
		assert media_feature_id_for_name(name) == none
		assert_media_feature_lookup_matches_name_chain(name, none)
	}
	for byte in 0 .. 256 {
		for name in all_media_feature_names() {
			mut mutated := name.bytes()
			mutated[name.len / 2] = u8(byte)
			assert_media_feature_lookup_matches_name_chain(mutated.bytestr(), none)
		}
	}
}

fn test_media_feature_name_classification_does_not_retain_caller_storage() {
	$if prealloc {
		mut storage := platform.new_arena('media feature lookup caller')
		entry := storage.enter()
		names := all_media_feature_names()
		before := storage.usage().used
		for _ in 0 .. 64 {
			for name in names {
				assert media_feature_id_for_name(name) != none
			}
		}
		assert storage.usage().used == before
		storage.leave(entry)
		storage.release()
		assert media_feature_id_for_name('resolution')? == .resolution
	}
}

fn test_media_feature_lookup_tracks_direct_expression_name_edits() {
	mut document := dom.Document.create(dom.url_about_blank())
	defer { document.finalize() }
	document.set_viewport_rect(dom.Rect{0, 0, 800, 0})
	query := parse_media_query_from_text('(width)')?
	mut feature := query.media_condition or { panic('missing condition') }
	for feature.children.len > 0 { feature = feature.children[0] }
	assert feature.media_feature_name == 'width'
	for name, expected in {
		'width':           true
		'height':          false
		'unknown-feature': false
		'resolution':      true
		'WIDTH':           false
	} {
		feature.media_feature_name = name
		assert query.evaluate(document) == expected, name
	}
	feature.media_feature_name = 'width'
	assert query.evaluate(document)
	document.set_viewport_rect(dom.Rect{0, 0, 0, 0})
	assert !query.evaluate(document)
}
