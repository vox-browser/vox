module css

fn resolve_registered_property_urls(value StyleValue, base string) StyleValue {
	if value is StyleValueList {
		mut values := []StyleValue{}
		for item in value.values() { values << resolve_registered_property_urls(item, base) }
		return StyleValue(StyleValueList.create(values, value.separator(), value.collapsible_))
	}
	if value is URLStyleValue {
		url := value.url()
		resolved := resolve_css_url_with_base(url.url(), base) or { return value }
		return StyleValue(URLStyleValue.create(URL.new(resolved, url.type_, url.request_url_modifiers)))
	}
	if value is ImageStyleValue {
		url := value.url_
		resolved := resolve_css_url_with_base(url.url(), base) or { return value }
		return StyleValue(ImageStyleValue.create(URL.new(resolved, url.type_, url.request_url_modifiers)))
	}
	return value
}
