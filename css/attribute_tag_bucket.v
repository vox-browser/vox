module css

import os

const disable_attribute_tag_buckets = os.getenv('VOX_DISABLE_ATTRIBUTE_TAG_BUCKETS') != ''
const attribute_tag_bucket_diagnostics = os.getenv('VOX_ATTRIBUTE_TAG_BUCKET_DIAGNOSTICS') != ''

// A required attribute is usually more selective than a tag, especially for
// cosmetic-filter rules such as div[id^="ad-"]. Keep class/ID buckets and
// namespace-dependent attributes on their existing paths. Bucket membership
// is only a necessary condition; the ordinary matcher still checks the entire
// selector, including attribute values, namespace, tag and pseudo-elements.
fn style_scope_attribute_before_tag_bucket(compound CompoundSelector) ?string {
	if disable_attribute_tag_buckets { return none }
	mut has_tag := false
	mut attribute_name := ?string(none)
	for index := compound.simple_selectors.len - 1; index >= 0; index-- {
		component := &compound.simple_selectors[index]
		if component.type_ in [.class, .id] { return none }
		if simplified := style_scope_is_roundabout_selector_bucketable_as_something_simpler(*component) {
			if simplified.type_ in [.class, .id] { return none }
		}
		if component.type_ == .tag_name { has_tag = true }
		if component.type_ == .attribute && attribute_name == none {
			attribute := component.attribute()
			if attribute.qualified_name.namespace_type in [.default_, .none]
				&& !attribute.qualified_name.name.name.contains(':') {
				attribute_name = attribute.qualified_name.name.lowercase_name
			}
		}
	}
	return if has_tag { attribute_name } else { none }
}

fn record_attribute_before_tag_bucket(selector Selector) {
	if attribute_tag_bucket_diagnostics {
		eprintln('Vox attribute/tag buckets: ${selector.text()}')
	}
}
