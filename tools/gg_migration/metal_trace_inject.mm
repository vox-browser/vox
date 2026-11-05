// DYLD_INSERT_LIBRARIES entry point for metal_trace.mm: traces every Metal
// pipeline and draw of a process into $VOX_METAL_TRACE_DIR.
#include "metal_trace.h"
#include <cstdlib>
#include <string>
#include <unistd.h>

__attribute__((constructor)) static void vox_metal_trace_inject()
{
    char const* directory = std::getenv("VOX_METAL_TRACE_DIR");
    if (!directory || !*directory) return;
    vox_metal_trace_install(directory);
    std::string name = "process-" + std::to_string(getpid());
    vox_metal_trace_begin(directory, name.c_str());
}
