//
//  SVGAParser.h
//  SVGAPlayer
//
//  Created by 崔明辉 on 16/6/17.
//  Copyright © 2016年 UED Center. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SVGAVideoEntity;

@interface SVGAParser : NSObject

@property (nonatomic, assign) BOOL enabledMemoryCache;

- (void)parseWithData:(nonnull NSData *)data
             cacheKey:(nonnull NSString *)cacheKey
      completionBlock:(void ( ^ _Nullable)(SVGAVideoEntity * _Nonnull videoItem))completionBlock
         failureBlock:(void ( ^ _Nullable)(NSError * _Nonnull error))failureBlock;

- (void)parseWithNamed:(nonnull NSString *)named
              inBundle:(nullable NSBundle *)inBundle
       completionBlock:(void ( ^ _Nullable)(SVGAVideoEntity * _Nonnull videoItem))completionBlock
          failureBlock:(void ( ^ _Nullable)(NSError * _Nonnull error))failureBlock;

@end
