//
//  WQVoiceCache.h
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//  非单例每个对象都可以有自己的存储类

#import <Foundation/Foundation.h>
static NSString * const WQVoiceErrorDomain = @"WQVoiceErrorDomain";
/** 文件来源类型 */
typedef NS_ENUM(NSInteger,WQVoiceCacheType) {
    WQVoiceCacheTypeNone,
    WQVoiceCacheTypeDisk,
    WQVoiceCacheTypeMemory,
};


///** 文件缓存类型 */
//typedef enum : NSUInteger {
//    WQVoiceCachePolicyNone,//直接加载到内存中不缓存
//    WQVoiceCachePolicyToDisk,//直接存储到磁盘上
//    WQVoiceCachePolicyMemoryCache,//加载到内存中并缓存
//} WQVoiceCachePolicy;

typedef void (^WQVoiceQueryCompleteBlock) (NSString *voicePath,WQVoiceCacheType cacheType);
@interface WQVoiceCache : NSObject
//TODO: 工具方法
/** 字符串md5转换 */
+ (NSString *)md5WithString:(NSString *)string;

+ (void)moveFile:(NSString *)fromPath toPath:(NSString *)toPath;

+ (BOOL)isFileExists: (NSString *)path;

+ (long long)fileSizeWithPath: (NSString *)path;

+ (void)removeFileAtPath: (NSString *)path;
/** 语音缓存路径 */
+ (NSString *)voiceCacheTempPath;
//TODO: =====工具方法 End====

+ (instancetype)sharedCache;

//@property (assign ,nonatomic) WQVoiceCachePolicy cachePolicy;

/** 默认通过内存缓存 */
- (instancetype)initWithNamespace:(NSString *)name;
/**
 初始化语音文件的路径
 
 @param name 路径子目录
 @param directory 语音文件存储的根路径
 */
- (instancetype)initWithNamespace:(NSString *)name diskCacheDirectory:(NSString *)directory;

//- (instancetype)initWithNamespace:(NSString *)name diskCacheDirectory:(NSString *)directory cachePolicy:(WQVoiceCachePolicy)cachePolicy;

/** 存储语音(本地都是存储iOS可播放的音频(不带后缀名)) */
- (void)storeVoice:(NSData *)voiceData forKey:(NSString *)key;
/** 存储文件中查询录音文件是否存在 */
- (BOOL)diskVoiceExistsWithKey:(NSString *)key;

/** 根据URL获取全路径 */
-(NSString *)cachePathForURL:(NSString *)url;

/** 根据key获取文件的路径 */
- (NSString *)defaultCachePathForKey:(NSString *)key;

/** 根据路径获取文件存储的名字 */
- (NSString *)cacheKeyForURL:(NSString *)url;
/** 根据Key值查询语音 */
- (void)queryVoiceCacheForKey:(NSString *)key done:(WQVoiceQueryCompleteBlock)doneBlock;

/** 清除文件 */
- (void)clearCacheWithURL:(NSString *)url;
@end
