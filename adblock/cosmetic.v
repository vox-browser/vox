module adblock

import os

pub struct DocumentFilters {
pub:
	css        string
	scriptlets string
	procedural []string
	filters    []string
}

// Tokens are the live document's IDs and classes, prefixed with # and . as in
// uBO's content surveyor. Domain-specific and high-generic rules need no token.
pub fn document_filters(document_url string, tokens []string) !DocumentFilters {
	if !is_enabled() || (!document_url.starts_with('https://')
		&& !document_url.starts_with('http://')) {
		return DocumentFilters{}
	}
	source := 'JSON.stringify(voxDocumentFilters(${encode_transport_json(document_url)}, ${encode_transport_json(tokens)}))'
	memo_enabled := os.getenv('VOX_DISABLE_DOCUMENT_FILTER_MEMO') != '1'
	return query_document_filters(source, memo_enabled)
}

// Stylesheet refreshes need only CSS. Reusing its immutable memo avoids
// decoding and copying the scriptlets and rule lists on every DOM refresh.
pub fn document_css(document_url string, tokens []string) !string {
	if !is_enabled() || (!document_url.starts_with('https://')
		&& !document_url.starts_with('http://')) {
		return ''
	}
	source := 'JSON.stringify(voxDocumentFilters(${encode_transport_json(document_url)}, ${encode_transport_json(tokens)}))'
	memo_enabled := os.getenv('VOX_DISABLE_DOCUMENT_FILTER_MEMO') != '1'
	if memo_enabled {
		if css := retained_document_filter_css(source) { return css }
	}
	filters := query_document_filters(source, memo_enabled)!
	if memo_enabled { retain_document_filter_css(source, filters.css) }
	return filters.css
}

fn query_document_filters(source string, memo_enabled bool) !DocumentFilters {
	if memo_enabled {
		if result := retained_document_filters(source) {
			record_document_filter_memo(true, source.len, result.len)
			return decode_transport_json[DocumentFilters](result)
		}
	}
	result := evaluate_engine(source)!
	filters := decode_transport_json[DocumentFilters](result)!
	if memo_enabled { retain_document_filters(source, result) }
	record_document_filter_memo(false, source.len, result.len)
	return filters
}

// Run the publisher's procedural-selector implementation against the browser's
// real DOM. The platform adapter replaces extension stylesheet messaging with a
// returned user stylesheet; native document updates drive subsequent commits.
pub fn procedural_script(filters DocumentFilters) string {
	if filters.procedural.len == 0 { return '' }
	source := $embed_file('extended/procedural.js').to_string()
	return '(function(){
		let sequence=0;const styles=[];
		const vAPI={hideStyle:"display:none!important;",randomToken:()=>"data-vox-adblock-"+(++sequence)};
		${source}
		const owner={addCSS:code=>styles.push(code),commit(){},hasListeners:()=>false};
		const procedural=new vAPI.DOMProceduralFilterer(owner);
		vAPI.domFilterer={proceduralFilterer:procedural};
		procedural.addProceduralSelectors(${encode_transport_json(filters.procedural)}.map(s=>JSON.parse(s)));
		const proceduralCSS=()=>"/* vox procedural filters */\\n"+styles.join("\\n");
		globalThis.__voxAdblockProceduralCSS=proceduralCSS;
		globalThis.__voxAdblockApplyProcedural=()=>{procedural.commitNow();return proceduralCSS()};
	})();'
}
