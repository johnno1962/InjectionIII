//
//  main.m
//  signer
//
//  Created by John Holdsworth on 03/11/2017.
//  Copyright © 2017 John Holdsworth. All rights reserved.
//

#import "SignerService.h"

int main(int argc, const char *argv[]) {
    [SignerService runServer:@":8899"];
    return 0;
}
