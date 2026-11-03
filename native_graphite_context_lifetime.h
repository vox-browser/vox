#pragma once

#include <cstdio>
#include <cstdlib>
#include <dlfcn.h>
#include <pthread.h>

// Browser raster calls return owned CPU pixels synchronously. On the owner
// thread an inactive backend can therefore retire before its peer creates a
// context, without dropping either backend's reusable CPU raster results.
// Worker calls keep their existing independent mutex/ownership behavior.
inline void vox_retire_other_graphite_context(char const* library, char const* symbol)
{
    if (!pthread_main_np() || std::getenv("VOX_DISABLE_GRAPHICS_CONTEXT_HANDOFF")) return;
    // An unused backend must remain unloaded. No Skia object crosses this ABI.
    if (void* handle = dlopen(library, RTLD_LAZY | RTLD_LOCAL | RTLD_NOLOAD)) {
        auto retire = reinterpret_cast<int (*)()>(dlsym(handle, symbol));
        int retired = retire ? retire() : 0;
        if (retired && std::getenv("VOX_GRAPHICS_CONTEXT_DIAGNOSTICS"))
            std::fprintf(stderr, "VOX_GRAPHICS_CONTEXT_HANDOFF retired=%s\n", symbol);
        dlclose(handle);
    }
}
