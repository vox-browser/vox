module css

pub fn (computed &ComputedProperties) text_orientation() Keyword {
 value := computed.typed_property_value(.text_orientation) or { return .mixed }
 return value.to_keyword()
}
