module css

fn font_face_descriptors_can_export(descriptors []FontFaceDescriptor) bool {
	for descriptor in descriptors {
		if value := descriptor.style_value {
			if !font_face_value_can_export(value) { return false }
		}
	}
	return true
}

fn font_face_value_can_export(value StyleValue) bool {
	return match value {
		FontStyleStyleValue {
			if angle := value.angle() { property_value_can_export(angle) } else { true }
		}
		OpenTypeTaggedStyleValue { property_value_can_export(value.value()) }
		StyleValueList { value.values_.all(font_face_value_can_export(it)) }
		else { property_value_can_export(value) }
	}
}

// Only the parsed descriptors escape conversion. Source texts, token trees,
// superseded descriptors and parser intermediates can all retire together.
fn own_parsed_font_face_descriptor(descriptor FontFaceDescriptor) FontFaceDescriptor {
	return FontFaceDescriptor{
		id: descriptor.id
		value: descriptor.value.clone()
		font_sources: descriptor.font_sources.map(own_parsed_font_face_source(it))
		unicode_ranges: descriptor.unicode_ranges.clone()
		style_value: if parsed := descriptor.style_value { ?StyleValue(export_property_value(parsed)) } else { none }
	}
}

fn own_parsed_font_face_source(source FontSourceStyleValue) FontSourceStyleValue {
	parsed := source.source()
	payload := match parsed {
		FontSourceLocal {
			FontSourceStyleValueSource(FontSourceLocal{ name: export_property_value(parsed.name) })
		}
		URL {
			modifiers := parsed.request_url_modifiers.map(own_font_face_url_modifier(it))
			FontSourceStyleValueSource(URL.new(parsed.url_.clone(), parsed.type_, modifiers))
		}
	}
	format := if name := source.format() { ?string(name.clone()) } else { none }
	return FontSourceStyleValue.create(payload, format, source.tech().clone())
}

fn own_font_face_url_modifier(modifier RequestURLModifier) RequestURLModifier {
	return match modifier.type_ {
		.cross_origin {
			RequestURLModifier.create_cross_origin(modifier.value_ as CrossOriginModifierValue)
		}
		.integrity { RequestURLModifier.create_integrity((modifier.value_ as string).clone()) }
		.referrer_policy {
			RequestURLModifier.create_referrer_policy(modifier.value_ as ReferrerPolicyModifierValue)
		}
	}
}
