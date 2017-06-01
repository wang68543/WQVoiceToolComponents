//
//  WQVoiceCache.m
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import "WQVoiceCache.h"
#import <CommonCrypto/CommonDigest.h>
#define kCachePath [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject]
#define kTmpPath NSTemporaryDirectory()

@interface WQVoiceCache(){
    dispatch_queue_t _ioQueue;
}
@property (copy ,nonatomic) NSString *diskCachePath;
@end
@implementation WQVoiceCache
static WQVoiceCache *_instance;
+(instancetype)sharedCache{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] initWithNamespace:@"WQVoiceBasicCache"];
    });
    return _instance;
}

/** 如果路径不存在就创建 */
-(NSError *)createPathIfNotExtist:(NSString *)path{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if([fileManager fileExistsAtPath:path isDirectory:NULL]){
        return nil;
    }else{
        [self createPathIfNotExtist:[path stringByDeletingLastPathComponent]];
        NSError *error ;
        if(path.pathExtension.length <= 0){
            [fileManager createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&error];
        }
        return error;
    }
}
-(NSString *)pathForVoiceDirectory{
    return   [kCachePath stringByAppendingPathComponent:@"com.WQVoiceManager.Cache"];
}
-(instancetype)initWithNamespace:(NSString *)name{
    return [self initWithNamespace:name diskCacheDirectory:nil];
}
-(instancetype)initWithNamespace:(NSString *)name diskCacheDirectory:(NSString *)directory{
    if(self = [self init]){
        if(!directory || directory.length <= 0){
            directory =  [self pathForVoiceDirectory];
        }
        NSString *cachePath = [directory stringByAppendingPathComponent:name];
        NSError *error = [self createPathIfNotExtist:cachePath];
        if(error){//创建出错就使用默认路径
            self.diskCachePath = [[self pathForVoiceDirectory] stringByAppendingPathComponent:name];
        }else{
            self.diskCachePath = cachePath;
        }
        _ioQueue = dispatch_queue_create("com.WQVoiceCache", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}
//TODO: 保存文件
-(void)storeVoice:(NSData *)voiceData forKey:(NSString *)key{
    if(voiceData){
        dispatch_async(_ioQueue, ^{
            [voiceData writeToFile:[self.diskCachePath stringByAppendingPathComponent:key] atomically:YES];
        });
       
    }
}

//TODO: 查询缓存中是否有语音
-(void)queryVoiceCacheForKey:(NSString *)key done:(WQVoiceQueryCompleteBlock)doneBlock{
    dispatch_async(_ioQueue, ^{
        NSString *voicePath = [self diskVoicePathForKey:key];
        if(doneBlock){
            dispatch_async(dispatch_get_main_queue(), ^{
                if(voicePath){
                    doneBlock(voicePath,WQVoiceCacheTypeDisk);
                }else{
                    doneBlock(nil,WQVoiceCacheTypeNone);
                }
            });
        }
    });
   
}

//MARK: 音频缓存路径
-(NSString *)diskVoicePathForKey:(NSString *)key{
    NSString *voicePath = [self defaultCachePathForKey:key];
    if([WQVoiceCache isFileExists:voicePath]){
        return voicePath;
    }else{
        return nil;
    }
}
//TODO: 根据key读取文件
-(NSData *)diskVoiceForKey:(NSString *)key{
    return [NSData dataWithContentsOfFile:[self defaultCachePathForKey:key]];
}
//TODO: 根据key判断文件是否存在
-(BOOL)diskVoiceExistsWithKey:(NSString *)key{
    return [WQVoiceCache isFileExists:[self defaultCachePathForKey:key]];
}
//TODO: 根据URL获取全路径
-(NSString *)cachePathForURL:(NSString *)url{
    return [self defaultCachePathForKey:[self cacheKeyForURL:url]];
}
//TODO: 根据key获取全路径
-(NSString *)defaultCachePathForKey:(NSString *)key{
    return [self.diskCachePath stringByAppendingPathComponent:key];
}
//TODO: 根据URL获取key
-(NSString *)cacheKeyForURL:(NSString *)url{
    if(!url || url.length <= 0){
        return @"";
    }
    return [WQVoiceCache md5WithString:url];
}
- (void)dealloc{
    _ioQueue = nil;
}
//TODO: 根据URL清除缓存
-(void)clearCacheWithURL:(NSString *)url{
    [WQVoiceCache removeFileAtPath:[self cachePathForURL:url]];
}
#pragma mark -- 工具方法
+(long long)fileSizeWithPath:(NSString *)path{
    if (![self isFileExists:path]) {
        return 0;
    }
    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    long long size = [fileInfo[NSFileSize] longLongValue];
    
    return size;
}
+(BOOL)isFileExists:(NSString *)path{
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}
+ (void)moveFile:(NSString *)fromPath toPath: (NSString *)toPath {
    if (![self isFileExists:fromPath]) {
        return;
    }
    [[NSFileManager defaultManager] moveItemAtPath:fromPath toPath:toPath error:nil];
}
+ (void)removeFileAtPath: (NSString *)path {
    if (![self isFileExists:path]) {
        return;
    }
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}

+(NSString *)voiceCacheTempPath{
    return kTmpPath ;
}
//TODO: 字符串md5转换
+ (NSString *)md5WithString:(NSString *)string{
    const char *data = string.UTF8String;
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data, (CC_LONG)strlen(data), digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i ++) {
        [result appendFormat:@"%02x", digest[i]];
    }
    return result;
    
}

@end
