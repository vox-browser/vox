// Selection namespace facade. The implementation lives in dom/selection.v so
// Range and Selection can share their object graph without a module cycle.
module selection

import dom

pub fn selection_create(doc &dom.Document) &dom.Selection {
	return dom.Selection.create(doc)
}
