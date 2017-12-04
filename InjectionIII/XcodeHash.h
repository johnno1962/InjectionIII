//
//  XcodeHash.h
//  Refactorator
//
//  Created by John Holdsworth on 19/11/2016.
//

#import <Cocoa/Cocoa.h>

@interface XcodeHash : NSObject
+ (NSString *)hashStringForPath:(NSString *)path;
@end
