#ifndef VOX_BROWSERJS_RUNTIME_AGENT_CONTEXT_H
#define VOX_BROWSERJS_RUNTIME_AGENT_CONTEXT_H

#include <JavaScriptCore/JavaScript.h>
#include <pthread.h>

// A context group owns the VM, including reusable parsed code. Keep one per
// agent thread, while every Runtime still gets a new global object and realm.
// JSC binds deferred VM work to the creating thread's run loop; never share
// this cache across threads. Release it when a worker thread exits.
static pthread_once_t vox_browserjs_agent_key_once = PTHREAD_ONCE_INIT;
static pthread_key_t vox_browserjs_agent_key;
static int vox_browserjs_agent_key_ready;

static void vox_browserjs_release_agent_group(void *group)
{
    JSContextGroupRelease((JSContextGroupRef)group);
}

static void vox_browserjs_make_agent_key(void)
{
    vox_browserjs_agent_key_ready =
        pthread_key_create(&vox_browserjs_agent_key,
            vox_browserjs_release_agent_group) == 0;
}

static JSGlobalContextRef vox_browserjs_create_agent_context(void)
{
    pthread_once(&vox_browserjs_agent_key_once, vox_browserjs_make_agent_key);
    if (!vox_browserjs_agent_key_ready)
        return JSGlobalContextCreate(NULL);
    JSContextGroupRef group = pthread_getspecific(vox_browserjs_agent_key);
    if (!group) {
        group = JSContextGroupCreate();
        if (!group)
            return NULL;
        if (pthread_setspecific(vox_browserjs_agent_key, group) != 0) {
            JSContextGroupRelease(group);
            return JSGlobalContextCreate(NULL);
        }
    }
    return JSGlobalContextCreateInGroup(group, NULL);
}

#endif
