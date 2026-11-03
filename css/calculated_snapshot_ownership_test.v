module css

import dom

fn test_calculated_dimensions_are_not_document_wide_scalar_snapshots() {
	base := computed_properties_with_initial_values()
	_ = resolve_computed_values(base)
	assert idle_layout_snapshot_is_shareable(base.computed_layout_cache())
	// fit-content also carries a LengthPercentage without SizeType.calculated.
	for size in [Size.make_calculated(CalculatedStyleValue{}),
		Size.make_fit_content(LengthPercentage.from_calculated(CalculatedStyleValue{}))] {
		$for field in ComputedLayoutCache.fields {
			$if field.typ is Size {
				mut copy := ComputedLayoutCache{ ...base.computed_layout_cache() }
				copy.$(field.name) = size
				assert !idle_layout_snapshot_is_shareable(&copy), field.name
			}
		}
	}
}

fn calculated_snapshot_style(document &dom.Document, source string) &ComputedProperties {
	mut style := computed_properties_with_initial_values()
	style.set_property(.width, parse_css_value(ParsingParams{}, source, .width) or {
		panic('invalid calculated width')
	}, .no, .no)
	_ = resolve_computed_values_for_document(style, document)
	return style
}

fn test_calculated_dimensions_keep_style_local_storage_across_raw_graph_replacement() {
	mut document := dom.Document.create(dom.url_about_blank())
	document.set_browsing_context(&dom.BrowsingContext{ active_document_: document })
	document.enable_native_storage()
	mut scope := document.enter_native_storage()
	defer {
		scope.finish()
		document.release_native_storage()
	}
	mut first := calculated_snapshot_style(document, 'calc(100% - 20px)')
	second := calculated_snapshot_style(document, 'calc(100% - 20px)')
	previous := second.computed_layout_cache()
	assert !idle_layout_snapshot_is_shareable(previous)
	assert share_idle_layout_snapshots([first, second]) == 0
	assert voidptr(first.computed_layout_cache()) != voidptr(previous)
	first.set_property(.width, parse_css_value(ParsingParams{}, 'calc(100% - 30px)', .width) or {
		panic('invalid replacement width')
	}, .no, .no)
	_ = resolve_computed_values_for_document(first, document)
	context := LengthResolutionContext.default()
	basis := CSSPixels.new(200)
	assert previous.computed_values_width_.length_percentage().to_px(context, basis).to_double() == 180
	assert first.computed_layout_cache().computed_values_width_.length_percentage().to_px(context, basis).to_double() == 170
	$if prealloc {
		computer := css_style_computer_for(document)
		for _, bucket in computer.initial_layout_snapshots_.buckets {
			for cached in bucket {
				assert !cached.computed_values_width_.is_calculated()
			}
		}
	}
}
