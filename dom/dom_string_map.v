module dom

// DOMStringMap backs HTMLElement.dataset: a live view of an element's `data-*` attributes, keyed by
// the camelCase form (so `data-foo-bar` <-> `fooBar`). https://html.spec.whatwg.org/#domstringmap
pub struct DOMStringMap {
pub mut:
	associated_element &Element = unsafe { nil }
}

pub fn DOMStringMap.create(element &Element) &DOMStringMap {
	return &DOMStringMap{
		associated_element: element
	}
}

// `data-foo-bar` -> `fooBar`: drop the `data-` prefix, then remove each hyphen that precedes a
// lowercase ASCII letter and uppercase that letter (other hyphens are kept, per the spec).
fn attribute_name_to_dataset_key(attribute_name string) string {
	name := if attribute_name.starts_with('data-') { attribute_name[5..] } else { attribute_name }
	mut result := ''
	mut i := 0
	for i < name.len {
		c := name[i]
		if c == 45 && i + 1 < name.len && name[i + 1] >= 97 && name[i + 1] <= 122 { // '-' then a-z
			result += (name[i + 1] - 32).ascii_str() // uppercase the letter
			i += 2
		} else {
			result += c.ascii_str()
			i++
		}
	}
	return result
}

// `fooBar` -> `data-foo-bar`: prefix `data-`, then replace each uppercase ASCII letter with a hyphen
// and its lowercase form.
fn dataset_key_to_attribute_name(key string) string {
	mut result := 'data-'
	for c in key.bytes() {
		if c >= 65 && c <= 90 { // A-Z
			result += '-'
			result += (c + 32).ascii_str() // lowercase
		} else {
			result += c.ascii_str()
		}
	}
	return result
}

// The value of the `data-*` attribute for `key`, or none when it isn't set.
pub fn (d &DOMStringMap) get(key string) ?string {
	return d.associated_element.get_attribute(dataset_key_to_attribute_name(key))
}

// Whether the `data-*` attribute for `key` is set.
pub fn (d &DOMStringMap) contains(key string) bool {
	return d.associated_element.has_attribute(dataset_key_to_attribute_name(key))
}

// Set the `data-*` attribute for `key`.
pub fn (d &DOMStringMap) set(key string, value string) {
	mut element := unsafe { &Element(d.associated_element) }
	element.set_attribute_value(dataset_key_to_attribute_name(key), value)
}

// Remove the `data-*` attribute for `key`.
pub fn (d &DOMStringMap) remove(key string) {
	mut element := unsafe { &Element(d.associated_element) }
	element.remove_attribute(dataset_key_to_attribute_name(key))
}

// The camelCase keys of all the element's `data-*` attributes, in attribute order.
pub fn (d &DOMStringMap) keys() []string {
	mut result := []string{}
	for name in d.associated_element.get_attribute_names() {
		if name.starts_with('data-') {
			result << attribute_name_to_dataset_key(name)
		}
	}
	return result
}

// The element's `data-*` attributes as a DOMStringMap. https://html.spec.whatwg.org/#dom-dataset
pub fn (e &Element) dataset() &DOMStringMap {
	return DOMStringMap.create(e)
}
