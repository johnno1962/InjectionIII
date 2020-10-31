//
//  InjectionClient.h
//  InjectionBundle
//
//  Created by John Holdsworth on 06/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "SimpleSocket.h"
#import "/tmp/InjectionSalt.h"

#define INJECTION_ADDRESS @":8898"
#define INJECTION_KEY @"bvijkijyhbtrbrebzjbbzcfbbvvq"
#define FRAMEWORK_DELIMITER @","
#define CALLORDER_DELIMITER @"---"

@interface InjectionClient : SimpleSocket

@end

typedef NS_ENUM(int, InjectionCommand) {
    // commands to Bundle
    InjectionConnected,
    InjectionWatching,
    InjectionLog,
    InjectionSigned,
    InjectionLoad,
    InjectionInject,
    InjectionIdeProcPath,
    InjectionXprobe,
    InjectionEval,
    InjectionVaccineSettingChanged,

    InjectionTrace,
    InjectionUntrace,
    InjectionTraceUI,
    InjectionTraceUIKit,
    InjectionTraceSwiftUI,
    InjectionTraceFramework,
    InjectionQuietInclude,
    InjectionInclude,
    InjectionExclude,
    InjectionStats,
    InjectionCallOrder,
    InjectionFileOrder,
    InjectionFileReorder,
    InjectionUninterpose,

    InjectionInvalid = 1000,

    InjectionEOF = ~0
};

typedef NS_ENUM(int, InjectionResponse) {
    // responses from bundle
    InjectionComplete,
    InjectionPause,
    InjectionSign,
    InjectionError,
    InjectionFrameworkList,
    InjectionCallOrderList,

    InjectionExit = ~0
};

