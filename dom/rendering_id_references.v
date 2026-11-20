module dom

import os

// Same-binary control for rendering_element_by_id: every id that enters,
// leaves or changes in the document lookup map rebuilds the layout tree again.
const rebuild_layout_for_every_id_change = os.getenv('VOX_REBUILD_LAYOUT_FOR_EVERY_ID_CHANGE') != ''
