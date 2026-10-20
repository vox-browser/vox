#ifndef VOX_RETAINED_ARENA_MAPPING_TEST_H
#define VOX_RETAINED_ARENA_MAPPING_TEST_H
#include <stdint.h>
#include <sys/mman.h>
#include <unistd.h>
#ifdef __APPLE__
#include <mach/mach.h>
#include <mach/mach_vm.h>
#endif
static int vox_retained_test_page_mapped(void* address) {
#ifdef __APPLE__
    // Darwin mincore succeeds for unmapped holes too. Query the actual region
    // and reject a later region returned after the requested address.
    mach_vm_address_t region=(uintptr_t)address;
    mach_vm_size_t size=0;
    vm_region_basic_info_data_64_t info={0};
    mach_msg_type_number_t count=VM_REGION_BASIC_INFO_COUNT_64;
    mach_port_t object=MACH_PORT_NULL;
    kern_return_t result=mach_vm_region(mach_task_self(),&region,&size,
        VM_REGION_BASIC_INFO_64,(vm_region_info_t)&info,&count,&object);
    if(object!=MACH_PORT_NULL) mach_port_deallocate(mach_task_self(),object);
    return result==KERN_SUCCESS && region<=(uintptr_t)address && (uintptr_t)address<region+size;
#else
    uintptr_t page=(uintptr_t)sysconf(_SC_PAGESIZE);
    void* start=(void*)((uintptr_t)address & ~(page-1));
    unsigned char state=0;
    return mincore(start,page,&state)==0;
#endif
}
static int vox_retained_test_mapping_probe_works(void) {
    size_t size=(size_t)sysconf(_SC_PAGESIZE)*2;
    void* data=mmap(0,size,PROT_READ|PROT_WRITE,MAP_ANONYMOUS|MAP_PRIVATE,-1,0);
    if(data==MAP_FAILED) return 0;
    int mapped=vox_retained_test_page_mapped(data);
    int result=munmap(data,size);
    return mapped && result==0 && !vox_retained_test_page_mapped(data);
}
#endif
