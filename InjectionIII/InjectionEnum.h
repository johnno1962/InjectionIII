//
//  InjectionEnum.h
//  InjectionIII
//
//  Created by Francisco Javier Trujillo Mata on 19/04/2019.
//  Copyright © 2019 John Holdsworth. All rights reserved.
//

#ifndef InjectionEnum_h
#define InjectionEnum_h

#define INJECTION_ADDRESS @":8898"
#define INJECTION_KEY @"bvijkijyhbtrbrebzjbbzcfbbvvq"

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

#endif /* InjectionEnum_h */
