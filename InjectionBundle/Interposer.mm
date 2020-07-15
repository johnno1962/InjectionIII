//
//  Interposter.m
//  InjectionBundle
//
//  Created by John Holdsworth on 11/07/2020.
//  Copyright © 2020 John Holdsworth. All rights reserved.
//
//  $Id: //depot/ResidentEval/InjectionBundle/Interposer.mm#7 $
//

#import <Foundation/Foundation.h>
#import "XprobeSwift-Bridging-Header.h"

// thanks to https://stackoverflow.com/questions/20481058/find-pathname-from-dlopen-handle-on-osx

#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/arch.h>
#import <mach-o/getsect.h>
#import <mach-o/nlist.h>

#ifdef __LP64__
typedef struct mach_header_64 mach_header_t;
typedef struct segment_command_64 segment_command_t;
typedef struct nlist_64 nlist_t;
typedef uint64_t sectsize_t;
#define getsectdatafromheader_f getsectdatafromheader_64
#else
typedef struct mach_header mach_header_t;
typedef struct segment_command segment_command_t;
typedef struct nlist nlist_t;
typedef uint32_t sectsize_t;
#define getsectdatafromheader_f getsectdatafromheader
#endif

void findSwiftFunctions(const char *bundlePath, const char *suffix,
                        void (^callback)(void *func, const char *sym)) {

    for (int32_t i = _dyld_image_count()-1; i >= 0 ; i--) {
        const mach_header_t *header = (const mach_header_t *)_dyld_get_image_header(i);
        const char *imageName = _dyld_get_image_name(i);
        if (!(imageName && (!bundlePath || imageName == bundlePath || strstr(imageName, bundlePath))))
            continue;

        segment_command_t *seg_linkedit = nullptr;
        segment_command_t *seg_text = nullptr;
        struct symtab_command *symtab = nullptr;
        
        struct load_command *cmd = (struct load_command *)((intptr_t)header + sizeof(mach_header_t));
        for (uint32_t i = 0; i < header->ncmds; i++, cmd = (struct load_command *)((intptr_t)cmd + cmd->cmdsize))
        {
            switch(cmd->cmd)
            {
                case LC_SEGMENT:
                case LC_SEGMENT_64:
                    if (!strcmp(((segment_command_t *)cmd)->segname, SEG_TEXT))
                        seg_text = (segment_command_t *)cmd;
                    else if (!strcmp(((segment_command_t *)cmd)->segname, SEG_LINKEDIT))
                        seg_linkedit = (segment_command_t *)cmd;
                    break;

                case LC_SYMTAB: {
                    symtab = (struct symtab_command *)cmd;
                    intptr_t file_slide = ((intptr_t)seg_linkedit->vmaddr - (intptr_t)seg_text->vmaddr) - seg_linkedit->fileoff;
                    const char *strings = (const char *)header + (symtab->stroff + file_slide);
                    nlist_t *sym = (nlist_t *)((intptr_t)header + (symtab->symoff + file_slide));
                    size_t suffix_len = strlen(suffix);

                    for (uint32_t i = 0; i < symtab->nsyms; i++, sym++) {
                        const char *sptr = strings + sym->n_un.n_strx;
                        void *aFunc;
                        if (sym->n_type == 0xf &&
                            strncmp(sptr, "_$s", 3) == 0 &&
                            strcmp(sptr+strlen(sptr)-suffix_len, suffix) == 0 &&
                            (aFunc = (void *)(sym->n_value + (intptr_t)header - (intptr_t)seg_text->vmaddr))) {
                            callback(aFunc, sptr+1);
                        }
                    }

                    if (bundlePath)
                        return;
                }
            }
        }
        NSLog(@"Unable to locate last loaded dylib %s c.f. %s",
              bundlePath, imageName);
    }
}

void findImages(void (^callback)(const char *sym, const struct mach_header *)) {
    for (int32_t i = _dyld_image_count()-1; i >= 0 ; i--) {
        const char *imageName = _dyld_get_image_name(i);
//        NSLog(@"findImages: %s", imageName);
        if (strstr(imageName, "/Containers/") ||
            strstr(imageName, ".app/Contents/MacOS/") ||
            strstr(imageName, "/T/eval"))
            callback(imageName, _dyld_get_image_header(i));
    }
}
