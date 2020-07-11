//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "../XprobePlugin/Classes/Xtrace.h"
#import "../XprobePlugin/Classes/Xprobe.h"
#import "../SwiftTrace/SwiftTrace/SwiftTrace.h"

@interface NSObject(InjectionSweep)
- (void)bsweep;
@end

// declare these here for while we wait for a modulemap

struct dyld_interpose_tuple {
  const void * _Nonnull replacement;
  const void * _Nonnull replacee;
};

/// Very handy albeit private API on dynamic loader.
void dyld_dynamic_interpose(
    const struct mach_header * _Nonnull mh,
    const struct dyld_interpose_tuple array[_Nonnull],
    size_t count) __attribute__((weak_import));

/// Find Swift functions and initializers with given suffix.
void findSwiftFunctions(const char * _Nonnull bundlePath,
                        const char * _Nonnull suffix,
                        void (^ _Nonnull callback)(void * _Nonnull func,
                                         const char * _Nonnull sym));

/// Iterate over images injected or in the application bundle.
void findImages(void (^ _Nonnull callback)(const struct mach_header * _Nonnull header));
