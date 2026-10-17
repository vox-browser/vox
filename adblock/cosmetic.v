module adblock

import json2

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
	result := evaluate_engine('JSON.stringify(voxDocumentFilters(${json2.encode(document_url, escape_unicode: true)}, ${json2.encode(tokens, escape_unicode: true)}))')!
	return json2.decode[DocumentFilters](result)
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
		procedural.addProceduralSelectors(${json2.encode(filters.procedural, escape_unicode: true)}.map(s=>JSON.parse(s)));
		const proceduralCSS=()=>"/* vox procedural filters */\\n"+styles.join("\\n");
		globalThis.__voxAdblockProceduralCSS=proceduralCSS;
		globalThis.__voxAdblockApplyProcedural=()=>{procedural.commitNow();return proceduralCSS()};
	})();'
}
