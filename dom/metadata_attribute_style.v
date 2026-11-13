module dom

import os

const disable_metadata_attribute_style_reuse = os.getenv('VOX_DISABLE_METADATA_ATTRIBUTE_STYLE_REUSE') != ''

fn metadata_attribute_style_reuse(name string) bool {
	return !disable_metadata_attribute_style_reuse
		&& (name.starts_with('data-') || name.starts_with('aria-'))
}
