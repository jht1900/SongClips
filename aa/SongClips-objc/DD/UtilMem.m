/*
 Copyright (C) 2008 John Henry Thompson. All Rights Reserved.
 */

#import "UtilMem.h"

#include <sys/sysctl.h>

static int inital_free_mem = 0;

// --------------------------------------------------------------------------------------------------------
int sys_get_phys_mem()
{
	int mib[] = { CTL_HW, HW_PHYSMEM };
	size_t mem;
	size_t len = sizeof(mem);
	sysctl(mib, 2, &mem, &len, NULL, 0);
	return (int)mem;
}

// --------------------------------------------------------------------------------------------------------
int sys_test_allocsize(int index)
{
	if (! inital_free_mem)
		inital_free_mem = sys_get_free_memory();
	
	//return inital_free_mem / 2;
	switch (index)
	{
	case 0:
		return inital_free_mem ;
	case 1:
		return inital_free_mem / 2;
	case 2:
		return inital_free_mem / 4;
	case 3:
		return inital_free_mem / 8;
	}
	return inital_free_mem;
}

// --------------------------------------------------------------------------------------------------------
int sys_get_process_count()
{
    int                 err;

    static const int    name[] = { CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0 };
    // Declaring name as const requires us to cast it when passing it to
    // sysctl because the prototype doesn't include the const modifier.
    size_t              length;

	length = 0;
	err = sysctl( (int *) name, (sizeof(name) / sizeof(*name)) - 1,
				 NULL, &length,
				 NULL, 0);

	return (int)length / sizeof(struct kinfo_proc);
}

// --------------------------------------------------------------------------------------------------------
natural_t sys_get_free_memory ()
{
    mach_port_t host_port;
    mach_msg_type_number_t host_size;
    vm_size_t pagesize;
	
    host_port = mach_host_self();
    host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    host_page_size(host_port, &pagesize);        
	
    vm_statistics_data_t vm_stat;
	
    if (host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size) != KERN_SUCCESS) 
	{
        NSLog(@"Failed to fetch vm statistics");
        return 0;
    }
	
    /* Stats in bytes */ 
    natural_t mem_free = (int)vm_stat.free_count * (int)pagesize;
	
    return mem_free;
}


// --------------------------------------------------------------------------------------------------------
// --------------------------------------------------------------------------------------------------------
