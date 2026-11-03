module css

// Read only already-computed ordinary URL images. Gradients, image-set
// selection and other image kinds keep the existing paint-resource path.
pub fn (properties &ComputedProperties) background_resource_urls() []string {
	value := properties.property(.background_image, .yes) or { return []string{} }
	if value.css_value_handle == unsafe { nil } { return []string{} }
	box := unsafe { &TypedStyleValueBox(value.css_value_handle) }
	mut urls := []string{}
	collect_computed_background_resource_urls(&box.value, mut urls)
	return urls
}

fn collect_computed_background_resource_urls(value &StyleValue, mut urls []string) {
	if value is ImageStyleValue {
		address := value.url_.url()
		if address.starts_with('http://') || address.starts_with('https://') { urls << address }
	} else if value is StyleValueList {
		for index in 0 .. value.values_.len {
			collect_computed_background_resource_urls(&value.values_[index], mut urls)
		}
	}
}
