//
//  WQVoiceCache.h
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//  非单例每个对象都可以有自己的存储类

#import <Foundation/Foundation.h>
static NSString * const WQVoiceErrorDomain = @"WQVoiceErrorDomain";

typedef NS_ENUM(NSInteger,WQVoiceCacheType) {
    WQVoiceCacheTypeNone,
    WQVoiceCacheTypeDisk,
    WQVoiceCacheTypeMemory,
};

typedef void (^WQVoiceQueryCompleteBlock) (NSData *voiceData,WQVoiceCacheType cacheType);
@interface WQVoiceCache : NSObject

+ (instancetype)sharedCache;

- (instancetype)initWithNamespace:(NSString *)name;

/**
 初始化语音文件的路径

 @param name 路径子目录
 @param directory 语音文件存储的根路径
 */
- (instancetype)initWithNamespace:(NSString *)name diskCacheDirectory:(NSString *)directory;

/**根据路径获取文件存储的名字*/
- (NSString *)cacheKeyForURL:(NSString *)url;

/**存储语音(本地都是存储iOS可播放的音频(不带后缀名))*/
- (void)storeVoice:(NSData *)voiceData forKey:(NSString *)key;

/**存储文件中查询录音文件是否存在*/
- (BOOL)diskVoiceExistsWithKey:(NSString *)key;
/**根据key获取文件的路径*/
- (NSString *)defaultCachePathForKey:(NSString *)key;

/**根据Key值查询语音*/
- (void)queryVoiceCacheForKey:(NSString *)key done:(WQVoiceQueryCompleteBlock)doneBlock;
@end
