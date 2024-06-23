//
//  Use this file to import your target's public headers that you would like to expose to Swift.
//

#import "SimpleSocket.h"
#import "UserDefaults.h"
#import "InjectionClient.h"
#if SWIFT_PACKAGE
#import "../XprobePlugin/Sources/Xprobe/include/Xprobe.h"
#endif
#import "DLKitC.h"

@interface NSObject(InjectionSweep)
- (void)bsweep;
@end

@interface NSObject(RunXCTestCase)
+ (void)runXCTestCase:(Class)aTestCase;
@end
