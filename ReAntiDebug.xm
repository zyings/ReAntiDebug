#import <substrate.h>
#import <sys/sysctl.h>

static int (*orig_ptrace) (int request, pid_t pid, caddr_t addr, int data);
static int my_ptrace (int request, pid_t pid, caddr_t addr, int data){
    if(request == 31){
        NSLog(@"[ReAntiDebug] - ptrace request is PT_DENY_ATTACH");
        return 0;
    }
    return orig_ptrace(request,pid,addr,data);
}

static void* (*orig_dlsym)(void* handle, const char* symbol);
static void* my_dlsym(void* handle, const char* symbol){
    if(strcmp(symbol, "ptrace") == 0){
            NSLog(@"[ReAntiDebug] - dlsym get ptrace symbol");
            return (void*)my_ptrace;
    }
    return orig_dlsym(handle, symbol);
}

static int (*orig_sysctl)(int * name, u_int namelen, void * info, size_t * infosize, void * newinfo, size_t newinfosize);
static int my_sysctl(int * name, u_int namelen, void * info, size_t * infosize, void * newinfo, size_t newinfosize){
    int ret = orig_sysctl(name,namelen,info,infosize,newinfo,newinfosize);
    if(namelen == 4 && name[0] == 1 && name[1] == 14 && name[2] == 1){
        struct kinfo_proc *info_ptr = (struct kinfo_proc *)info;
        if(info_ptr && (info_ptr->kp_proc.p_flag & P_TRACED) != 0){
            NSLog(@"[ReAntiDebug] - sysctl query trace status.");
            info_ptr->kp_proc.p_flag ^= P_TRACED;
            if((info_ptr->kp_proc.p_flag & P_TRACED) == 0){
                NSLog(@"[ReAntiDebug] trace status reomve success!");
            }
        }
    }
    return ret;
}

static void* (*orig_syscall)(int code, va_list args);
static void* my_syscall(int code, va_list args){
    int request;
    va_list newArgs;
    va_copy(newArgs, args);
    if(code == 26){
        request = (long)args;
        if(request == 31){
            NSLog(@"[ReAntiDebug] - syscall call ptrace, and request is PT_DENY_ATTACH");
            return nil;
        }
    }
    return (void*)orig_syscall(code, newArgs);
}

%ctor{
    MSHookFunction((void *)MSFindSymbol(NULL,"_ptrace"),(void*)my_ptrace,(void**)&orig_ptrace);
    MSHookFunction((void *)dlsym,(void*)my_dlsym,(void**)&orig_dlsym);
    MSHookFunction((void *)sysctl,(void*)my_sysctl,(void**)&orig_sysctl);
    MSHookFunction((void *)syscall,(void*)my_syscall,(void**)&orig_syscall);

    NSLog(@"[ReAntiDebug] Module loaded!!!");
}
