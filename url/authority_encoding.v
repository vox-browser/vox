module url

import os

const retain_url_authority_concat = os.getenv('VOX_RETAIN_URL_AUTHORITY_CONCAT') != ''
const url_authority_diagnostics = os.getenv('VOX_URL_AUTHORITY_DIAGNOSTICS') != ''

__global url_authority_reported bool

fn parser_runes_to_string(input []rune, start int, end int) string {
	if end <= start { return '' }
	if !retain_url_authority_concat {
		// V's bulk rune encoder uses the same UTF-32 encoder as rune.str(),
		// with one growing byte buffer rather than a string allocation and
		// prefix copy for each authority code point. The slice never escapes.
		output := input[start..end].string()
		if url_authority_diagnostics && !url_authority_reported {
			url_authority_reported = true
			eprintln('Vox URL authority: bulk encoded runes=${end - start}')
		}
		return output
	}
	mut output := ''
	for index := start; index < end; index++ {
		output += input[index].str()
	}
	return output
}
