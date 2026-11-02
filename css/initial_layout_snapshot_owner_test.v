module css

import dom
import platform

fn verify_initial_snapshot_owner_after_animation_reset(prime_pool bool) {
	$if prealloc {
		mut document := dom.Document.create(dom.url_about_blank())
		document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
		document.enable_native_storage()
		mut scope := document.enter_native_storage()
		mut arena := platform.new_arena('initial snapshot animation reset')
		defer {
			scope.finish()
			document.release_native_storage()
			arena.release()
		}
		mut style := computed_properties_with_initial_values()
		style.set_property(.width, parse_css_value(ParsingParams{}, '73px', .width) or {
			panic('width')
		}, .no, .no)
		mut computer := css_style_computer_for(document)
		if prime_pool {
			warm := computed_properties_with_initial_values()
			_ = resolve_computed_values_for_document(warm, document)
			assert computer.initial_layout_snapshots_ != unsafe { nil }
		}
		// A final animation update can remove the animated properties before
		// resolving the target's ordinary values in the current sample arena.
		computer.animation_samples_ = &AnimationSampleStorage{ current: arena }
		computer.sampling_animation_frame_ = true
		computer.animation_layout_style_ = style
		assert !style.has_animated_properties()
		_ = resolve_computed_values_for_document(style, document)
		computer.sampling_animation_frame_ = false
		computer.animation_layout_style_ = unsafe { nil }
		computer.animation_samples_ = unsafe { nil }
		assert style.computed_layout_cache().computed_values_width_ == Size.make_length(Length.make_px(73))
		// The style's own sample can be tracked by animation retirement. A
		// document-wide interning pool is outside that target ownership graph.
		pool := computer.initial_layout_snapshots_
		assert !arena.contains(voidptr(pool))
		if pool != unsafe { nil } {
			for _, bucket in pool.buckets {
				for snapshot in bucket {
					assert !arena.contains(voidptr(snapshot))
				}
			}
		}
	}
}

fn test_animation_reset_does_not_create_a_sample_owned_initial_snapshot_pool() {
	verify_initial_snapshot_owner_after_animation_reset(false)
}

fn test_animation_reset_does_not_add_sample_snapshots_to_an_existing_initial_pool() {
	verify_initial_snapshot_owner_after_animation_reset(true)
}
