// SPDX-License-Identifier: BSD-2-Clause
module browserjs

import libjs

// A document entry includes its complete module graph and nested native
// callbacks. GitHub's Primer/React factory initialization exceeds the former
// one-million-instruction ceiling before reaching the page's render code.
const libjs_document_instruction_limit = u64(10000000)

fn (runtime &Runtime) libjs_execution_limits() libjs.ExecutionLimits {
	return libjs.ExecutionLimits{max_instructions: if runtime.libjs_document_host_ != none {
		libjs_document_instruction_limit
	} else { u64(1000000) }}
}
