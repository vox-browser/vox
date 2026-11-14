module main

import dom
import os

const disable_github_cosmetic_token_reuse = os.getenv('VOX_DISABLE_GITHUB_COSMETIC_TOKEN_REUSE') != ''
const github_cosmetic_token_diagnostics = os.getenv('VOX_GITHUB_COSMETIC_TOKEN_DIAGNOSTICS') != ''
const disable_chatgpt_cosmetic_token_reuse = os.getenv('VOX_DISABLE_CHATGPT_COSMETIC_TOKEN_REUSE') != ''
__global github_cosmetic_token_reuse_reported bool

struct SiteCosmeticTokenAttributeStamp {
	version u64
	tree_version u64
	id_class_only bool
}

// The cosmetic survey reads raw IDs/classes; procedural filters and CSS
// matching still observe every live attribute. Keep tree invalidation intact.
fn site_cosmetic_token_attribute_stamp(document &dom.Document) SiteCosmeticTokenAttributeStamp {
	address := document.url.serialize()
	chatgpt := address == 'https://chatgpt.com' || address.starts_with('https://chatgpt.com/')
	if (!disable_github_cosmetic_token_reuse && site_batches_image_completion_layout(address))
		|| (!disable_chatgpt_cosmetic_token_reuse && chatgpt) {
		return SiteCosmeticTokenAttributeStamp{document.light_dom_id_class_attribute_version(), document.light_dom_element_version(), true}
	}
	return SiteCosmeticTokenAttributeStamp{document.attribute_version(), document.dom_tree_version(), false}
}

fn report_site_cosmetic_token_reuse(scoped bool, inputs_changed bool) {
	if github_cosmetic_token_diagnostics && scoped && inputs_changed
		&& !github_cosmetic_token_reuse_reported {
		github_cosmetic_token_reuse_reported = true
		eprintln('Vox site cosmetic tokens: reused survey across non-token DOM updates')
	}
}
