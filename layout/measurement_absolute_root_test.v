module layout

import css

fn test_absolute_root_measurements_preserve_outer_positioning_and_owned_inner_geometry() {
	for kind in ['grid', 'flex'] {
		for rules in ['left:10%;top:5px;width:40%;height:25%',
			'inset:auto;width:max-content;height:auto',
			'left:5%;right:7%;top:10%;bottom:20%;width:auto;height:auto;direction:rtl'] {
			mut document := absolute_measurement_document(kind, '<div style="display:grid;grid-template-columns:1fr 1fr"><span>Nested wrapping alpha beta 😀 words.</span><span>Other text.</span></div><div style="position:absolute;right:10%;bottom:3px;width:60px">Inner absolute.</div>', 'position:absolute;'+rules)
			mut owner := document.enter_native_storage()
			defer { owner.finish(); document.finalize(); document.release_native_storage() }
			root := measurement_image_node(document, 'root')
			assert root.is_absolutely_positioned()
			mut source := LayoutState.new()
			source.enable_measurement_chunk_pool()
			source.measurement_chunk_pool_.scratch_enabled_ = true
			defer { source.release_measurement_chunk_pool() }
			for width in [120, 180] {
				assert !absolute_measurement_compare(mut source, root, width, 160, false)
				if width == 120 { assert !absolute_measurement_compare(mut source, root, width, 160, false) }
				for _ in 0 .. 3 {
					assert absolute_measurement_compare(mut source, root, width, 160, false) == (!retain_absolute_root_measurements && absolute_measurement_enabled(kind))
				}
				assert absolute_measurement_compare(mut source, root, width, 160, true) == (!retain_absolute_root_measurements && absolute_measurement_enabled(kind)
					&& if kind == 'grid' { !disable_committed_grid_measurement_reuse } else { !disable_committed_flex_measurement_reuse })
			}
		}
	}
}

fn test_absolute_root_measurements_keep_external_size_bases_exact() {
	for kind in ['grid', 'flex'] {
		mut document := absolute_measurement_document(kind, '<p>Wrapping text within an absolute root.</p>', 'position:absolute;left:10%;right:7%;top:5%;width:40%;height:25%')
		mut owner := document.enter_native_storage()
		defer { owner.finish(); document.finalize(); document.release_native_storage() }
		root := measurement_image_node(document, 'root')
		mut source := LayoutState.new()
		source.enable_measurement_chunk_pool()
		source.measurement_chunk_pool_.scratch_enabled_ = true
		defer { source.release_measurement_chunk_pool() }
		assert !absolute_measurement_compare_with_parent(mut source, root, 180, 160, false, 500, 300)
		assert !absolute_measurement_compare_with_parent(mut source, root, 180, 160, false, 500, 300)
		assert absolute_measurement_compare_with_parent(mut source, root, 180, 160, false, 500, 300) == (!retain_absolute_root_measurements && absolute_measurement_enabled(kind))
		for dimensions in [[700, 300], [500, 400], [700, 400]] {
			assert !absolute_measurement_compare_with_parent(mut source, root, 180, 160, false, dimensions[0], dimensions[1])
			assert absolute_measurement_compare_with_parent(mut source, root, 180, 160, false, dimensions[0], dimensions[1]) == (!retain_absolute_root_measurements && absolute_measurement_enabled(kind))
		}
		key := u64(voidptr(root))
		if kind == 'grid' {
			for entry in source.measurement_chunk_pool_.grid_measurements_[key] or { []&GridMeasurementLayout{} } { assert !entry.external_heights_independent }
		} else {
			for entry in source.measurement_chunk_pool_.flex_measurements_[key] or { []&FlexMeasurementLayout{} } { assert !entry.external_heights_independent }
		}
	}
}

fn test_absolute_root_measurements_invalidate_style_and_keep_specialized_outer_algorithms() {
	mut document := absolute_measurement_document('grid', '<p>Ordinary wrapping root content.</p>', 'position:absolute;width:40%;left:5px')
	mut owner := document.enter_native_storage()
	defer { owner.finish(); document.finalize(); document.release_native_storage() }
	root := measurement_image_node(document, 'root')
	mut source := LayoutState.new()
	source.enable_measurement_chunk_pool()
	source.measurement_chunk_pool_.scratch_enabled_ = true
	defer { source.release_measurement_chunk_pool() }
	assert !absolute_measurement_compare(mut source, root, 180, 160, false)
	assert !absolute_measurement_compare(mut source, root, 180, 160, false)
	assert absolute_measurement_compare(mut source, root, 180, 160, false) == (!retain_absolute_root_measurements && absolute_measurement_enabled('grid'))
	mut properties := unsafe { &css.ComputedProperties(root.computed_values()) }
	value := css.parse_css_value(css.ParsingParams{}, '17px', .left) or { panic('left') }
	properties.set_property(.left, value, .no, .no)
	assert !absolute_measurement_compare(mut source, root, 180, 160, false)
	for _ in 0 .. 2 { _ = absolute_measurement_compare(mut source, root, 180, 160, false) }
	for position in ['fixed', 'sticky'] {
		mut special := absolute_measurement_document('grid', '<p>Special root.</p>', 'position:'+position+';top:5px')
		mut special_owner := special.enter_native_storage()
		special_root := measurement_image_node(special, 'root')
		mut inputs := []RetainedInlineInput{}
		mut rejected := map[u64]bool{}
		assert !collect_grid_measurement_inputs(special_root, mut inputs, mut rejected)
		special_owner.finish(); special.finalize(); special.release_native_storage()
	}
}
