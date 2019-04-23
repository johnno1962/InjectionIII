//
//  InjectionClient.h
//  InjectionBundle
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "SimpleSocket.h"

@class SwiftInjection;

@interface InjectionClient : SimpleSocket

@property (nonatomic, strong, readonly) SwiftInjection *swiftInjection;

+ (void)createInjectionClient;

@end
