//
//  SVGAParser.m
//  SVGAPlayer
//
//  Created by 崔明辉 on 16/6/17.
//  Copyright © 2016年 UED Center. All rights reserved.
//

#import "SVGAParser.h"
#import "SVGAVideoEntity.h"
#import "Svga.pbobjc.h"
#import <zlib.h>
#import <CommonCrypto/CommonDigest.h>

#define ZIP_MAGIC_NUMBER "PK"

@interface SVGAParser ()

@end

@implementation SVGAParser

static NSOperationQueue *parseQueue;
static NSOperationQueue *unzipQueue;

+ (void)load {
    parseQueue = [NSOperationQueue new];
    parseQueue.maxConcurrentOperationCount = 8;
    unzipQueue = [NSOperationQueue new];
    unzipQueue.maxConcurrentOperationCount = 1;
}

- (void)parseWithNamed:(NSString *)named
              inBundle:(NSBundle *)inBundle
       completionBlock:(void (^)(SVGAVideoEntity * _Nonnull))completionBlock
          failureBlock:(void (^)(NSError * _Nonnull))failureBlock {
    NSString *filePath = [(inBundle ?: [NSBundle mainBundle]) pathForResource:named ofType:@"svga"];
    if (filePath == nil) {
        if (failureBlock) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                failureBlock([NSError errorWithDomain:@"SVGAParser" code:404 userInfo:@{NSLocalizedDescriptionKey: @"File not exist."}]);
            }];
        }
        return;
    }
    [self parseWithData:[NSData dataWithContentsOfFile:filePath]
               cacheKey:[self cacheKey:[NSURL fileURLWithPath:filePath]]
        completionBlock:completionBlock
           failureBlock:failureBlock];
}

- (void)parseWithCacheKey:(nonnull NSString *)cacheKey
          completionBlock:(void ( ^ _Nullable)(SVGAVideoEntity * _Nonnull videoItem))completionBlock
             failureBlock:(void ( ^ _Nullable)(NSError * _Nonnull error))failureBlock {
    [parseQueue addOperationWithBlock:^{
        SVGAVideoEntity *cacheItem = [SVGAVideoEntity readCache:cacheKey];
        if (cacheItem != nil) {
            if (completionBlock) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    completionBlock(cacheItem);
                }];
            }
            return;
        }
        NSString *cacheDir = [self cacheDirectory:cacheKey];
        if ([[NSFileManager defaultManager] fileExistsAtPath:[cacheDir stringByAppendingString:@"/movie.binary"]]) {
            NSError *err;
            NSData *protoData = [NSData dataWithContentsOfFile:[cacheDir stringByAppendingString:@"/movie.binary"]];
            SVGAProtoMovieEntity *protoObject = [SVGAProtoMovieEntity parseFromData:protoData error:&err];
            if (!err && [protoObject isKindOfClass:[SVGAProtoMovieEntity class]]) {
                SVGAVideoEntity *videoItem = [[SVGAVideoEntity alloc] initWithProtoObject:protoObject cacheDir:cacheDir];
                [videoItem resetImagesWithProtoObject:protoObject];
                [videoItem resetSpritesWithProtoObject:protoObject];
                [videoItem resetAudiosWithProtoObject:protoObject];
                if (self.enabledMemoryCache) {
                    [videoItem saveCache:cacheKey];
                } else {
                    [videoItem saveWeakCache:cacheKey];
                }
                if (completionBlock) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        completionBlock(videoItem);
                    }];
                }
            }
            else {
                if (failureBlock) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        failureBlock([NSError errorWithDomain:NSFilePathErrorKey code:-1 userInfo:nil]);
                    }];
                }
            }
        }
        else {
            NSError *err;
            NSData *JSONData = [NSData dataWithContentsOfFile:[cacheDir stringByAppendingString:@"/movie.spec"]];
            if (JSONData != nil) {
                NSDictionary *JSONObject = [NSJSONSerialization JSONObjectWithData:JSONData options:kNilOptions error:&err];
                if ([JSONObject isKindOfClass:[NSDictionary class]]) {
                    SVGAVideoEntity *videoItem = [[SVGAVideoEntity alloc] initWithJSONObject:JSONObject cacheDir:cacheDir];
                    [videoItem resetImagesWithJSONObject:JSONObject];
                    [videoItem resetSpritesWithJSONObject:JSONObject];
                    if (self.enabledMemoryCache) {
                        [videoItem saveCache:cacheKey];
                    } else {
                        [videoItem saveWeakCache:cacheKey];
                    }
                    if (completionBlock) {
                        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                            completionBlock(videoItem);
                        }];
                    }
                }
            }
            else {
                if (failureBlock) {
                    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                        failureBlock([NSError errorWithDomain:NSFilePathErrorKey code:-1 userInfo:nil]);
                    }];
                }
            }
        }
    }];
}

- (void)clearCache:(nonnull NSString *)cacheKey {
    NSString *cacheDir = [self cacheDirectory:cacheKey];
    [[NSFileManager defaultManager] removeItemAtPath:cacheDir error:NULL];
}

- (void)parseWithData:(nonnull NSData *)data
             cacheKey:(nonnull NSString *)cacheKey
      completionBlock:(void ( ^ _Nullable)(SVGAVideoEntity * _Nonnull videoItem))completionBlock
         failureBlock:(void ( ^ _Nullable)(NSError * _Nonnull error))failureBlock {
    SVGAVideoEntity *cacheItem = [SVGAVideoEntity readCache:cacheKey];
    if (cacheItem != nil) {
        if (completionBlock) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                completionBlock(cacheItem);
            }];
        }
        return;
    }
    if (!data || data.length < 4) {
        return;
    }
    // Maybe is SVGA 2.0.0
    [parseQueue addOperationWithBlock:^{
        NSData *inflateData = [self zlibInflate:data];
        NSError *err;
        SVGAProtoMovieEntity *protoObject = [SVGAProtoMovieEntity parseFromData:inflateData error:&err];
        if (!err && [protoObject isKindOfClass:[SVGAProtoMovieEntity class]]) {
            SVGAVideoEntity *videoItem = [[SVGAVideoEntity alloc] initWithProtoObject:protoObject cacheDir:@""];
            [videoItem resetImagesWithProtoObject:protoObject];
            [videoItem resetSpritesWithProtoObject:protoObject];
            [videoItem resetAudiosWithProtoObject:protoObject];
            if (self.enabledMemoryCache) {
                [videoItem saveCache:cacheKey];
            } else {
                [videoItem saveWeakCache:cacheKey];
            }
            if (completionBlock) {
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    completionBlock(videoItem);
                }];
            }
        }
    }];    
}

- (nonnull NSString *)cacheKey:(NSURL *)URL {
    return [self MD5String:URL.absoluteString];
}

- (nullable NSString *)cacheDirectory:(NSString *)cacheKey {
    NSString *cacheDir = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject];
    return [cacheDir stringByAppendingFormat:@"/%@", cacheKey];
}

- (NSString *)MD5String:(NSString *)str {
    const char *cstr = [str UTF8String];
    unsigned char result[16];
    CC_MD5(cstr, (CC_LONG)strlen(cstr), result);
    return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3],
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];
}

- (NSData *)zlibInflate:(NSData *)data
{
    if ([data length] == 0) return data;
    
    unsigned full_length = (unsigned)[data length];
    unsigned half_length = (unsigned)[data length] / 2;
    
    NSMutableData *decompressed = [NSMutableData dataWithLength: full_length + half_length];
    BOOL done = NO;
    int status;
    
    z_stream strm;
    strm.next_in = (Bytef *)[data bytes];
    strm.avail_in = (unsigned)[data length];
    strm.total_out = 0;
    strm.zalloc = Z_NULL;
    strm.zfree = Z_NULL;
    
    if (inflateInit (&strm) != Z_OK) return nil;
    
    while (!done)
    {
        // Make sure we have enough room and reset the lengths.
        if (strm.total_out >= [decompressed length])
            [decompressed increaseLengthBy: half_length];
        strm.next_out = [decompressed mutableBytes] + strm.total_out;
        strm.avail_out = (uInt)([decompressed length] - strm.total_out);
        
        // Inflate another chunk.
        status = inflate (&strm, Z_SYNC_FLUSH);
        if (status == Z_STREAM_END) done = YES;
        else if (status != Z_OK) break;
    }
    if (inflateEnd (&strm) != Z_OK) return nil;
    
    // Set real length.
    if (done)
    {
        [decompressed setLength: strm.total_out];
        return [NSData dataWithData: decompressed];
    }
    else return nil;
}

@end
