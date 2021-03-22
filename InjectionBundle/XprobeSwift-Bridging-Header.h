//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "InjectionClient.h"
#import "UserDefaults.h"
#import "../XprobePlugin/Sources/Xprobe/include/Xtrace.h"
#import "../XprobePlugin/Sources/Xprobe/include/Xprobe.h"

@interface NSObject(InjectionSweep)
- (void)bsweep;
@end

@interface NSObject(RunXCTestCase)
+ (void)runXCTestCase:(Class)aTestCase;
@end
