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
    WQVoiceCacheTypeNone,//来源于网络
    WQVoiceCacheTypeDisk,
    WQVoiceCacheTypeMemory,
};

typedef void (^WQVoiceQueryCompleteBlock) (NSString *cachePath,WQVoiceCacheType cacheType);
@interface WQVoiceCache : NSObject
//TODO: 工具方法
/** 字符串md5转换 */

//+ (NSString *)md5WithString:(NSString *)string;

//+ (void)moveFile:(NSString *)fromPath toPath:(NSString *)toPath;

//+ (BOOL)isFileExists: (NSString *)path;

//+ (long long)fileSizeWithPath: (NSString *)path;
//
//+ (void)removeFileAtPath: (NSString *)path;


/** 语音缓存目录 */
+ (NSString *)temVoiceCacheDirectory;
/** 语音缓存路径 */
+ (NSString *)tempVoiceCachePath:(NSString *)lastPathComment;

/**
 根据文件后缀名获取唯一文件名
 
 @param extension 文件后缀名
 */
+ (NSString *)uniqueRecordNameWithExtension:(NSString *)extension;

//TODO: =====工具方法 End====

+ (instancetype)sharedCache;

/** 默认通过内存缓存 */
- (instancetype)initWithNamespace:(NSString *)name;
/**
 初始化语音文件的路径
 
 @param name 路径子目录
 @param directory 语音文件存储的根路径
 */
- (instancetype)initWithNamespace:(NSString *)name diskCacheDirectory:(NSString *)directory;
/** 当前存储对象的目录*/
@property (copy ,nonatomic,readonly) NSString *diskCacheDirectory;

/** 根据路径获取文件存储的名字 */
- (NSString *)cacheKeyForURL:(NSURL *)url;


/** 存储语音(本地都是存储iOS可播放的音频(不带后缀名)) */
- (void)storeVoice:(NSData *)voiceData forKey:(NSString *)key;

/**
 将其他地方的本地录音文件存储到本地 (主要用于上传服务器拿到url之后 以及确定录音完成的时候(需要返回新路径))

 @param fromPath 源路径
 @param key key为空的话就以源路径获取Key
 @return 移动失败的原因
 */
- (NSError *)moveVoice:(NSString *)fromPath forkey:(NSString *)key;

/** 存储文件中查询录音文件是否存在 */
- (BOOL)diskVoiceExistsWithKey:(NSString *)key;

///** 根据URL获取全路径 */
//-(NSString *)cachePathForURL:(NSString *)url;

/** 根据url获取缓存路径 */
- (NSString *)defaultCachePathForURL:(NSURL *)url;
/** 根据key获取文件的路径 */
- (NSString *)defaultCachePathForKey:(NSString *)key;

/** 根据Key值查询语音 只查询当前目录 */
- (void)queryVoiceCacheForKey:(NSString *)key done:(WQVoiceQueryCompleteBlock)doneBlock;
/** 根据URL查询 如果是本地文件 会检测本地文件是否存在 (不局限于当前目录) */
- (void)queryVoiceCacheForURL:(NSURL *)url done:(WQVoiceQueryCompleteBlock)doneBlock;

/** 清除文件 */
//- (void)clearCacheWithURL:(NSString *)url;
@end
