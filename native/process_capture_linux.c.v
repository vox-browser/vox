module main

// Current V's process-capture object owns these helpers. Its native C backend
// can emit calls without the declarations from os; keep the ABI explicit.
#include "@VMODROOT/native/include/native_process_capture_compat.h"
