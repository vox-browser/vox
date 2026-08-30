module css

// Compact tagged state shared by upstream CSS value wrappers. It retains the
// serialized representation, numeric payload, children and boolean traits;
// the already-translated typed StyleValue variants remain the primary engine.
pub struct CSSValueFacade {
pub mut:
	kind       string
	text       string
	number     f64
	items      []string
	traits     map[string]bool
	style_sheet string
}

pub fn CSSValueFacade.create(text string) CSSValueFacade {
	return CSSValueFacade{text: text, kind: 'value', traits: map[string]bool{}}
}

pub fn (value CSSValueFacade) type_() string { return value.kind }
pub fn (value CSSValueFacade) serialize_text() string { return if value.text != '' { value.text } else { value.number.str() } }

pub fn (value CSSValueFacade) dump() string { return value.serialize_text() }
pub fn (value CSSValueFacade) to_string() string { return value.serialize_text() }
pub fn (value CSSValueFacade) serialize() string { return value.serialize_text() }
pub fn (value CSSValueFacade) color_syntax() string { return value.serialize_text() }
pub fn (value CSSValueFacade) color_type() string { return value.serialize_text() }
pub fn (value CSSValueFacade) serialize_alpha_component() string { return value.serialize_text() }
pub fn (value CSSValueFacade) serialize_color_component() string { return value.serialize_text() }
pub fn (value CSSValueFacade) serialize_hue_component() string { return value.serialize_text() }
pub fn (value CSSValueFacade) value() string { return value.serialize_text() }
pub fn (value CSSValueFacade) m_type() string { return value.serialize_text() }
pub fn (value CSSValueFacade) m_value() string { return value.serialize_text() }
pub fn (value CSSValueFacade) name() string { return value.serialize_text() }
pub fn (value CSSValueFacade) lowercase_name() string { return value.serialize_text() }
pub fn (value CSSValueFacade) qualified_name() string { return value.serialize_text() }
pub fn (value CSSValueFacade) pseudo_class() string { return value.serialize_text() }
pub fn (value CSSValueFacade) pseudo_element() string { return value.serialize_text() }
pub fn (value CSSValueFacade) attribute() string { return value.serialize_text() }
pub fn (value CSSValueFacade) ident() string { return value.serialize_text() }
pub fn (value CSSValueFacade) type_name() string { return value.serialize_text() }
pub fn (value CSSValueFacade) value_type() string { return value.serialize_text() }
pub fn (value CSSValueFacade) child() string { return value.serialize_text() }
pub fn (value CSSValueFacade) compound_selector() string { return value.serialize_text() }
pub fn (value CSSValueFacade) pt_name_selector() string { return value.serialize_text() }
pub fn (value CSSValueFacade) original_shorthand_value() string { return value.serialize_text() }
pub fn (value CSSValueFacade) associated_property() string { return value.serialize_text() }
pub fn (value CSSValueFacade) resolved_radius() f64 { return value.number }
pub fn (value CSSValueFacade) url() string { return value.serialize_text() }
pub fn (value CSSValueFacade) item_value() string { return value.serialize_text() }
pub fn (value CSSValueFacade) parent_style_sheet() string { return value.serialize_text() }
pub fn (value CSSValueFacade) document_or_shadow_root() string { return value.serialize_text() }
pub fn (value CSSValueFacade) parent_rule() string { return value.serialize_text() }
pub fn (value CSSValueFacade) loading_state() string { return value.serialize_text() }
pub fn (value CSSValueFacade) key() string { return value.serialize_text() }
pub fn (value CSSValueFacade) declaration() string { return value.serialize_text() }
pub fn (value CSSValueFacade) descriptors() string { return value.serialize_text() }
pub fn (value CSSValueFacade) internal_layer_name() string { return value.serialize_text() }
pub fn (value CSSValueFacade) loaded_style_sheet() string { return value.serialize_text() }
pub fn (value CSSValueFacade) parent_style_sheet_for_subresource() string { return value.serialize_text() }
pub fn (value CSSValueFacade) css_float() string { return value.serialize_text() }
pub fn (value CSSValueFacade) style_value_for_computed_property() string { return value.serialize_text() }
pub fn (value CSSValueFacade) default_namespace_rule() string { return value.serialize_text() }
pub fn (value CSSValueFacade) owner_rule() string { return value.serialize_text() }
pub fn (value CSSValueFacade) current_frame_bitmap() string { return value.serialize_text() }
pub fn (value CSSValueFacade) basic_shape() string { return value.serialize_text() }
pub fn (value CSSValueFacade) length_percentage() string { return value.serialize_text() }
pub fn (value CSSValueFacade) horizontal_radius() string { return value.serialize_text() }
pub fn (value CSSValueFacade) vertical_radius() string { return value.serialize_text() }
pub fn (value CSSValueFacade) font_status_promise() string { return value.serialize_text() }
pub fn (value CSSValueFacade) contains_percentage() bool { return value.text.contains('%') || value.traits['percentage'] }
pub fn (value CSSValueFacade) is_calculated() bool { return value.traits['calculated'] || value.kind == 'calculated' }
pub fn (value CSSValueFacade) is_percentage() bool { return value.text.contains('%') || value.traits['percentage'] }
pub fn (value CSSValueFacade) is_t() bool { return value.traits['t'] || value.kind == 't' }
pub fn (value CSSValueFacade) is_ident() bool { return value.traits['ident'] || value.kind == 'ident' }
pub fn (value CSSValueFacade) is_integer() bool { return value.traits['integer'] || value.kind == 'integer' }
pub fn (value CSSValueFacade) is_length() bool { return value.traits['length'] || value.kind == 'length' }
pub fn (value CSSValueFacade) is_ratio() bool { return value.traits['ratio'] || value.kind == 'ratio' }
pub fn (value CSSValueFacade) is_resolution() bool { return value.traits['resolution'] || value.kind == 'resolution' }
pub fn (value CSSValueFacade) is_unknown() bool { return value.traits['unknown'] || value.kind == 'unknown' }
pub fn (value CSSValueFacade) is_color() bool { return value.traits['color'] || value.kind == 'color' }
pub fn (value CSSValueFacade) is_url() bool { return value.traits['url'] || value.kind == 'url' }
pub fn (value CSSValueFacade) is_auto() bool { return value.traits['auto'] || value.kind == 'auto' }
pub fn (value CSSValueFacade) is_abstract_image() bool { return value.traits['abstract_image'] || value.kind == 'abstract_image' }
pub fn (value CSSValueFacade) is_color_function() bool { return value.traits['color_function'] || value.kind == 'color_function' }
pub fn (value CSSValueFacade) is_paintable() bool { return value.traits['paintable'] || value.kind == 'paintable' }
pub fn (value CSSValueFacade) is_known_pseudo_element_type() bool { return value.traits['known_pseudo_element_type'] || value.kind == 'known_pseudo_element_type' }
pub fn (value CSSValueFacade) is_basic_shape() bool { return value.traits['basic_shape'] || value.kind == 'basic_shape' }
pub fn (value CSSValueFacade) is_empty() bool { return value.traits['empty'] || value.kind == 'empty' }
pub fn (value CSSValueFacade) is_initial() bool { return value.traits['initial'] || value.kind == 'initial' }
pub fn (value CSSValueFacade) has_color() bool { return value.traits['color'] }
pub fn (value CSSValueFacade) has_contents() bool { return value.traits['contents'] }
pub fn (value CSSValueFacade) has_scroll_position() bool { return value.traits['scroll_position'] }
pub fn (value CSSValueFacade) evaluate() bool { return value.traits['true'] }
pub fn (value CSSValueFacade) compare() bool { return value.traits['compare'] }
pub fn (value CSSValueFacade) boolean() bool { return value.traits['true'] }
pub fn (value CSSValueFacade) half_range() bool { return value.traits['half_range'] }
pub fn (value CSSValueFacade) max() bool { return value.traits['max'] }
pub fn (value CSSValueFacade) min() bool { return value.traits['min'] }
pub fn (value CSSValueFacade) plain() bool { return value.traits['plain'] }
pub fn (value CSSValueFacade) range() bool { return value.traits['range'] }
pub fn (value CSSValueFacade) matches() bool { return value.traits['true'] }
pub fn (value CSSValueFacade) load_any_resources() bool { return value.traits['load_any_resources'] }
pub fn (value CSSValueFacade) has_associated_font_loader() bool { return value.traits['associated_font_loader'] }
pub fn (value CSSValueFacade) equals(other CSSValueFacade) bool { return value.kind == other.kind && value.text == other.text && value.number == other.number && value.items == other.items }
pub fn (value CSSValueFacade) properties_equal(other CSSValueFacade) bool { return value.equals(other) }
pub fn (value CSSValueFacade) is_same_type(other CSSValueFacade) bool { return value.kind == other.kind }
pub fn (value CSSValueFacade) to_px() f64 { return value.number }
pub fn (value CSSValueFacade) natural_aspect_ratio() f64 { return value.number }
pub fn (value CSSValueFacade) natural_height() f64 { return value.number }
pub fn (value CSSValueFacade) natural_width() f64 { return value.number }
pub fn (value CSSValueFacade) alpha() f64 { return value.number }
pub fn (value CSSValueFacade) h() f64 { return value.number }
pub fn (value CSSValueFacade) s() f64 { return value.number }
pub fn (value CSSValueFacade) l() f64 { return value.number }
pub fn (value CSSValueFacade) w() f64 { return value.number }
pub fn (value CSSValueFacade) b() f64 { return value.number }
pub fn (value CSSValueFacade) c() f64 { return value.number }
pub fn (value CSSValueFacade) a() f64 { return value.number }
pub fn (value CSSValueFacade) resolved_amount() f64 { return value.number }
pub fn (value CSSValueFacade) angle_degrees() f64 { return value.number }
pub fn (value CSSValueFacade) hash() u64 { return u64(value.text.len) }
pub fn (value CSSValueFacade) bucket1() u64 { return u64(value.text.len) }
pub fn (value CSSValueFacade) bucket2() u64 { return u64(value.text.len) }
pub fn (value CSSValueFacade) custom_property_count() u64 { return u64(value.text.len) }
pub fn (value CSSValueFacade) calculated() CSSValueFacade { return value }
pub fn (value CSSValueFacade) get_t() CSSValueFacade { return value }
pub fn (value CSSValueFacade) percentage() CSSValueFacade { return value }
pub fn (value CSSValueFacade) resolved() CSSValueFacade { return value }
pub fn (value CSSValueFacade) as_style_value() CSSValueFacade { return value }
pub fn (value CSSValueFacade) resolve_calculated() CSSValueFacade { return value }
pub fn (value CSSValueFacade) create_style_value() CSSValueFacade { return value }
pub fn (value CSSValueFacade) resolve_hue() CSSValueFacade { return value }
pub fn (value CSSValueFacade) resolve_with_reference_value() CSSValueFacade { return value }
pub fn (value CSSValueFacade) resolve_alpha() CSSValueFacade { return value }
pub fn (value CSSValueFacade) color_if_single_pixel_bitmap() CSSValueFacade { return value }
pub fn (value CSSValueFacade) reify() CSSValueFacade { return value }
pub fn (value CSSValueFacade) resolve_for_size() CSSValueFacade { return value }
pub fn (value CSSValueFacade) resolve_size() CSSValueFacade { return value }
pub fn (value CSSValueFacade) as_abstract_image() CSSValueFacade { return value }
pub fn (value CSSValueFacade) as_color() CSSValueFacade { return value }
pub fn (value CSSValueFacade) as_url() CSSValueFacade { return value }
pub fn (value CSSValueFacade) fallback_color() CSSValueFacade { return value }
pub fn (value CSSValueFacade) absolutized() CSSValueFacade { return value }
pub fn (value CSSValueFacade) for_document() CSSValueFacade { return value }
pub fn (value CSSValueFacade) for_element() CSSValueFacade { return value }
pub fn (value CSSValueFacade) for_layout_node() CSSValueFacade { return value }
pub fn (value CSSValueFacade) for_window() CSSValueFacade { return value }
pub fn (value CSSValueFacade) for_layout_node_with_style() CSSValueFacade { return value }
pub fn (value CSSValueFacade) to_path() CSSValueFacade { return value }
pub fn (value CSSValueFacade) make_auto() CSSValueFacade { return value }
pub fn (value CSSValueFacade) make_integer() CSSValueFacade { return value }
pub fn (value CSSValueFacade) children() []string { return value.items.clone() }
pub fn (value CSSValueFacade) ident_list() []string { return value.items.clone() }
pub fn (value CSSValueFacade) color_stop_list() []string { return value.items.clone() }
pub fn (value CSSValueFacade) declarations() []string { return value.items.clone() }
pub fn (value CSSValueFacade) properties() []string { return value.items.clone() }
pub fn (value CSSValueFacade) custom_properties() []string { return value.items.clone() }
pub fn (value CSSValueFacade) map_entries() []string { return value.items.clone() }
pub fn (value CSSValueFacade) css_rules_for_bindings() []string { return value.items.clone() }
pub fn (value CSSValueFacade) import_rules() []string { return value.items.clone() }
pub fn (value CSSValueFacade) owning_documents_or_shadow_roots() []string { return value.items.clone() }
pub fn (value CSSValueFacade) failed_fonts() []string { return value.items.clone() }
pub fn (value CSSValueFacade) loaded_fonts() []string { return value.items.clone() }
pub fn (value CSSValueFacade) loading_fonts() []string { return value.items.clone() }
pub fn (mut value CSSValueFacade) set_style_sheet(text string) { value.text = text }
pub fn (mut value CSSValueFacade) set_is_2d(text string) { value.text = text }
pub fn (mut value CSSValueFacade) set_namespace_uri(text string) { value.text = text }
pub fn (mut value CSSValueFacade) set_prefix(text string) { value.text = text }
pub fn (mut value CSSValueFacade) set_name(text string) { value.text = text }
pub fn (mut value CSSValueFacade) set_loading_state(text string) { value.text = text }
pub fn (mut value CSSValueFacade) set_css_float(text string) { value.text = text }
pub fn (mut value CSSValueFacade) set_declarations_from_text(text string) { value.text = text }
pub fn (mut value CSSValueFacade) set_property_style_value(text string) { value.text = text }
pub fn (mut value CSSValueFacade) set_the_declarations(text string) { value.text = text }
pub fn (mut value CSSValueFacade) report(text string) { value.text = text }
pub fn (mut value CSSValueFacade) set_percent_hint(text string) { value.text = text }
pub fn (value CSSValueFacade) tokenize() string { return value.serialize_text() }
pub fn (value CSSValueFacade) paint() string { return value.serialize_text() }
pub fn (value CSSValueFacade) image_style_value_finalize() string { return value.serialize_text() }
pub fn (value CSSValueFacade) collect_ancestor_hashes() string { return value.serialize_text() }
pub fn (value CSSValueFacade) for_each_type_and_exponent() string { return value.serialize_text() }
pub fn (value CSSValueFacade) empty_the_declarations() string { return value.serialize_text() }
pub fn (value CSSValueFacade) convert_declarations_to_specified_order() string { return value.serialize_text() }
pub fn (value CSSValueFacade) serialize_a_css_value() string { return value.serialize_text() }
pub fn (value CSSValueFacade) generated_style_properties_to_css_style_properties() string { return value.serialize_text() }
pub fn (value CSSValueFacade) add_associated_font_loader() string { return value.serialize_text() }
pub fn (value CSSValueFacade) register_pending_image_value() string { return value.serialize_text() }
pub fn (value CSSValueFacade) on_set_modified_from_js() string { return value.serialize_text() }
pub fn (value CSSValueFacade) find_matching_font_weight_ascending() string { return value.serialize_text() }
pub fn (value CSSValueFacade) find_matching_font_weight_descending() string { return value.serialize_text() }
pub fn (value CSSValueFacade) load_fonts_from_sheet() string { return value.serialize_text() }
pub fn (value CSSValueFacade) unload_fonts_from_sheet() string { return value.serialize_text() }

pub fn (value CSSValueFacade) snake_case() string { return value.text.to_lower().replace('-', '_') }
pub fn (value CSSValueFacade) set_style_sheet_value(style_sheet string) CSSValueFacade { mut result := value; result.style_sheet = style_sheet; return result }
pub fn (value CSSValueFacade) to_string_list() []string { return value.items.clone() }
pub fn (value CSSValueFacade) none_() bool { return value.kind == 'none' }
pub fn (value CSSValueFacade) window() string { return value.text }
pub fn (value CSSValueFacade) the() string { return value.text }
pub fn (value CSSValueFacade) to_px_slow_case() f64 { return value.number }
