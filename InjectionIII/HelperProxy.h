//
//  HelperProxy.h
//  Smuggler
//
//  Created by John Holdsworth on 24/06/2016.
//  Copyright © 2016 John Holdsworth. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface HelperProxy : NSObject

+ (BOOL)inject:(NSString *)bundlePath error:(NSError **)error;

@end
