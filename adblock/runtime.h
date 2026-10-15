// Serializes the shared isolated JavaScriptCore engine. Page JS never sees it.
#ifndef VOX_ADBLOCK_RUNTIME_H
#define VOX_ADBLOCK_RUNTIME_H
#include <pthread.h>
#include <string.h>
static pthread_mutex_t vox_adblock_mutex = PTHREAD_MUTEX_INITIALIZER;
static void *vox_adblock_context_value = NULL;
static int vox_adblock_enabled_value = 1;
static char *vox_adblock_error_value = NULL;
static char *vox_adblock_get_error(void) { return vox_adblock_error_value; }
static void vox_adblock_set_error(const char *message) { vox_adblock_error_value = strdup(message); }
static void vox_adblock_lock(void) { pthread_mutex_lock(&vox_adblock_mutex); }
static void vox_adblock_unlock(void) { pthread_mutex_unlock(&vox_adblock_mutex); }
static void *vox_adblock_get_context(void) { return vox_adblock_context_value; }
static void vox_adblock_set_context(void *context) { vox_adblock_context_value = context; }
static int vox_adblock_get_enabled(void) { return vox_adblock_enabled_value; }
static void vox_adblock_set_enabled(int enabled) { vox_adblock_enabled_value = enabled; }
#endif
