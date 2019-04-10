//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#if __has_include("../XprobePlugin/Classes/Xtrace.h")
#import "../XprobePlugin/Classes/Xtrace.h"
#elif __has_include("Xtrace.h")
#import "Xtrace.h"
#endif

#if __has_include("../XprobePlugin/Classes/Xprobe.h")
#import "../XprobePlugin/Classes/Xprobe.h"
#elif __has_include("Xprobe.h")
#import "Xprobe.h"
#endif

@interface NSObject(InjectionSweep)
- (void)bsweep;
@end
