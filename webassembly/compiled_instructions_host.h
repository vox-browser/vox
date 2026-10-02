/* AK::atomic_load/store acquire/release ABI from LibWasm/Types.h. */
#pragma once
#include <stdint.h>

static inline uintptr_t vox_wasm_compiled_entry_acquire(uintptr_t const* slot)
{
    return __atomic_load_n(slot, __ATOMIC_ACQUIRE);
}

static inline void vox_wasm_compiled_entry_publish(uintptr_t* slot, uintptr_t entry)
{
    __atomic_store_n(slot, entry, __ATOMIC_RELEASE);
}
