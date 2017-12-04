//
//  XcodeHash.m
//  Refactorator
//
//  Created by John Holdsworth on 19/11/2016.
//

#import "XcodeHash.h"

#import <CommonCrypto/CommonCrypto.h>

@implementation XcodeHash

// Thanks to: http://samdmarshall.com/blog/xcode_deriveddata_hashes.html

// this function is used to swap byte ordering of a 64bit integer
static uint64_t swap_uint64(uint64_t val) {
    val = ((val << 8) & 0xFF00FF00FF00FF00ULL ) | ((val >> 8) & 0x00FF00FF00FF00FFULL );
    val = ((val << 16) & 0xFFFF0000FFFF0000ULL ) | ((val >> 16) & 0x0000FFFF0000FFFFULL );
    return (val << 32) | (val >> 32);
}

/*!
 @method hashStringForPath

 Create the unique identifier string for a Xcode project path

 @param path (input) string path to the ".xcodeproj" or ".xcworkspace" file

 @result NSString* of the identifier
 */
+ (NSString *)hashStringForPath:(NSString *)path;
{
    // using uint64_t[2] for ease of use, since it is the same size as char[CC_MD5_DIGEST_LENGTH]
    uint64_t digest[CC_MD2_DIGEST_LENGTH] = {0};

    // char array that will contain the identifier
    unsigned char resultStr[28] = {0};

    // setup md5 context
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);

    // get the UTF8 string of the path
    const char *c_path = [path UTF8String];

    // get length of the path string
    unsigned long length = strlen(c_path);

    // update the md5 context with the full path string
    CC_MD5_Update (&md5, c_path, (CC_LONG)length);

    // finalize working with the md5 context and store into the digest
    CC_MD5_Final ( (unsigned char *)digest, &md5);

    // take the first 8 bytes of the digest and swap byte order
    uint64_t startValue = swap_uint64(digest[0]);

    // for indexes 13->0
    int index = 13;
    do {
        // take 'startValue' mod 26 (restrict to alphabetic) and add based 'a'
        resultStr[index] = (char)((startValue % 26) + 'a');

        // divide 'startValue' by 26
        startValue /= 26;

        index--;
    } while (index >= 0);

    // The second loop, this time using the last 8 bytes
    // repeating the same process as before but over indexes 27->14
    startValue = swap_uint64(digest[1]);
    index = 27;
    do {
        resultStr[index] = (char)((startValue % 26) + 'a');
        startValue /= 26;
        index--;
    } while (index > 13);

    //return [[NSString alloc] initWithString:@"agyjsqofsyrdwafqcrbciitvnmmj"];
    // create a new string from the 'resultStr' char array and return
    return [[NSString alloc] initWithBytes:resultStr length:28 encoding:NSUTF8StringEncoding];
}

@end

