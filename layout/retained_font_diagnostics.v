module layout

import os

// Counting instructions must not enable per-cache-hit tracing. Keep these
// verbose records in explicitly requested diagnostic runs.
const retained_font_generation_diagnostics = os.getenv('VOX_RETAINED_FONT_DIAGNOSTICS') != ''
