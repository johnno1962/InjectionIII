//
//  InjectionServer.h
//  InjectionIII
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "SimpleSocket.h"

#define INJECTION_ADDRESS @":8898"
#define INJECTION_KEY @"bvijkijyhbtrbrebzjbbzcfbbvvq"

@interface InjectionServer : SimpleSocket

- (void)setProject:(NSString *)project;
- (void)injectPending;

@end

typedef NS_ENUM(int, InjectionCommand) {
    // responses from bundle
    InjectionComplete,
    InjectionPause,
    InjectionSign,
    InjectionError,

    // commands to Bundle
    InjectionProject,
    InjectionLog,
    InjectionSigned,
    InjectionLoad,
    InjectionInject,
    InjectionXprobe,
    InjectionEval,
    InjectionVaccineSettingChanged,

    InjectionEOF = ~0
};
