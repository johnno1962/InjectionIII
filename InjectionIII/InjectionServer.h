//
//  InjectionServer.h
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "SimpleSocket.h"
#import "InjectionEnum.h"

@interface InjectionServer : SimpleSocket

- (void)setProject:(NSString *)project;
- (void)injectPending;

@end
