module dom

import os

// Same-binary control: sample scroll-driven animations only in the next
// animation frame, as before (Document.update_layout()).
const disable_scroll_timeline_layout_validation = os.getenv('VOX_DISABLE_SCROLL_TIMELINE_LAYOUT_VALIDATION') != ''
