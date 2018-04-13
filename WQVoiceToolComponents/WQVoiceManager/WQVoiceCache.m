//
//  WQVoiceCache.m
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import "WQVoiceCache.h"
#import <UIKit/UIKit.h>

#import <CommonCrypto/CommonDigest.h>
#define kCachePath [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject]
#define kTmpPath NSTemporaryDirectory()

@interface WQVoiceCache(){
    dispatch_queue_t _ioQueue;
}
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
        NSFileManager *defaultManager = [NSFileManager defaultManager];
        if(![defaultManager fileExistsAtPath:cachePath]){
            NSError *error;
            [defaultManager createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:&error];
            if(error){//创建出错就使用默认路径
                _diskCacheDirectory = [[self pathForVoiceDirectory] stringByAppendingPathComponent:name];
            }else{
                _diskCacheDirectory = cachePath;
            }
        }else{
            _diskCacheDirectory = cachePath;
        }
        
        _ioQueue = dispatch_queue_create("com.WQVoiceCache", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

//TODO: - --将其他地方的本地录音文件存储到本地
- (NSError *)moveVoice:(NSString *)fromPath forkey:(NSString *)key{
    NSError *error;
    if (![[NSFileManager defaultManager] fileExistsAtPath:fromPath]) {
        error = [NSError errorWithDomain:WQVoiceErrorDomain code:-500 userInfo:@{NSLocalizedDescriptionKey :@"源文件路径不存在"}];
    }else{
        
        if (key == nil) {
           key = [self cacheKeyForURL:[NSURL URLWithString:fromPath]];
        }
        
        
        if (key == nil) {
            error = [NSError errorWithDomain:WQVoiceErrorDomain code:-500 userInfo:@{NSLocalizedDescriptionKey :@"存储路径初始化失败"}];
        }else{
            [[NSFileManager defaultManager] moveItemAtPath:fromPath toPath:[self defaultCachePathForKey:key] error:&error];
        }
    }
    return error;
}
//TODO: 保存文件
-(void)storeVoice:(NSData *)voiceData forKey:(NSString *)key{
    if(voiceData){
        dispatch_async(_ioQueue, ^{
            [voiceData writeToFile:[_diskCacheDirectory stringByAppendingPathComponent:key] atomically:YES];
        });
       
    }
}
//MARK: - -- 根据URL查询 如果是本地文件 会检测本地文件是否存在 (不局限于当前目录)
- (void)queryVoiceCacheForURL:(NSURL *)url done:(WQVoiceQueryCompleteBlock)doneBlock{
    if (!url && doneBlock) {
        doneBlock(nil,WQVoiceCacheTypeNone);
    }
    
    dispatch_async(_ioQueue, ^{
        NSString *cachePath ;
        if (url.scheme == nil ||  [url.scheme compare:@"file" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
            if ([self _isFileExists:url.path]) {
                cachePath = url.path;
            }
        }
        if (cachePath == nil) {//本地目录查询失败
            cachePath = [self defaultCachePathForURL:url];
            if (![self _isFileExists:cachePath]) {
                cachePath = nil;
            }
        }
        if(doneBlock){
            dispatch_async(dispatch_get_main_queue(), ^{
                if(cachePath){
                    doneBlock(cachePath,WQVoiceCacheTypeDisk);
                }else{
                    doneBlock(nil,WQVoiceCacheTypeNone);
                }
            });
        }
    });
}
//TODO: 查询缓存中是否有语音
-(void)queryVoiceCacheForKey:(NSString *)key done:(WQVoiceQueryCompleteBlock)doneBlock{
    dispatch_async(_ioQueue, ^{
        NSString *cachePath = [self defaultCachePathForKey:key];
        if (![self _isFileExists:cachePath]) {
            cachePath = nil;
        }
        if(doneBlock){
            dispatch_async(dispatch_get_main_queue(), ^{
                if(cachePath){
                    doneBlock(cachePath,WQVoiceCacheTypeDisk);
                }else{
                    doneBlock(nil,WQVoiceCacheTypeNone);
                }
            });
        }
    });
}
//TODO: 根据key读取文件
-(NSData *)diskVoiceForKey:(NSString *)key{
    return [NSData dataWithContentsOfFile:[self defaultCachePathForKey:key]];
}
//TODO: 根据key判断文件是否存在
-(BOOL)diskVoiceExistsWithKey:(NSString *)key{
    return [self _isFileExistsWithKey:key];
}

//TODO: 根据url获取缓存路径
- (NSString *)defaultCachePathForURL:(NSURL *)url{
    return [self defaultCachePathForKey:[self cacheKeyForURL:url]];
}
//TODO: 根据key获取全路径
-(NSString *)defaultCachePathForKey:(NSString *)key{
    return [_diskCacheDirectory stringByAppendingPathComponent:key];
}
//TODO: 根据URL获取key
-(NSString *)cacheKeyForURL:(NSURL *)url{
    if(!url){
        return @"";
    }
    return [self _MD5WithString:url.absoluteString];
}
- (void)dealloc{
    _ioQueue = nil;
}
//TODO: 根据URL清除缓存
//-(void)clearCacheWithURL:(NSURL *)url{
//    [WQVoiceCache removeFileAtPath:[self defaultCachePathForKey:[self cacheKeyForURL:url]]];
//}
#pragma mark -- 工具方法
//+(long long)fileSizeWithPath:(NSString *)path{
//    if (![self isFileExists:path]) {
//        return 0;
//    }
//    NSDictionary *fileInfo = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
//    long long size = [fileInfo[NSFileSize] longLongValue];
//
//    return size;
//}
-(BOOL)_isFileExists:(NSString *)path{
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

-(BOOL)_isFileExistsWithKey:(NSString *)key{
    return [[NSFileManager defaultManager] fileExistsAtPath:[self defaultCachePathForKey:key]];
}
//+ (void)moveFile:(NSString *)fromPath toPath: (NSString *)toPath {
//    if (![self isFileExists:fromPath]) {
//        return;
//    }
//    [[NSFileManager defaultManager] moveItemAtPath:fromPath toPath:toPath error:nil];
//}
//+ (void)removeFileAtPath: (NSString *)path {
//    if (![self isFileExists:path]) {
//        return;
//    }
//    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
//}

+(NSString *)voiceCacheTempPath{
    return kTmpPath ;
}
//TODO: 字符串md5转换
- (NSString *)_MD5WithString:(NSString *)string{
    const char *data = string.UTF8String;
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5(data, (CC_LONG)strlen(data), digest);
    NSMutableString *result = [NSMutableString stringWithCapacity:CC_MD5_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_MD5_DIGEST_LENGTH; i ++) {
        [result appendFormat:@"%02x", digest[i]];
    }
    return result;
    
}
//MARK: - -- 录音暂存路径
+ (NSString *)temVoiceCacheDirectory{
    return NSTemporaryDirectory();
}
+(NSString *)tempVoiceCachePath:(NSString *)lastPathComment{
    return [[self temVoiceCacheDirectory] stringByAppendingPathComponent:lastPathComment];
}
+(NSString *)uniqueRecordNameWithExtension:(NSString *)extension{
    return [self tempVoiceCachePath:[NSString stringWithFormat:@"%@.%@",[self _defaultRecordName],extension]];
}
//MARK: =========== 私有方法 ===========
+(NSString *)_defaultRecordName{
    NSString *recordName = [UIDevice currentDevice].identifierForVendor.UUIDString;
    recordName = [recordName stringByReplacingOccurrencesOfString:@"-" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, recordName.length-1)];
    recordName = [NSString stringWithFormat:@"%@%lf",recordName,[[NSDate date] timeIntervalSince1970]];
    return  [recordName stringByReplacingOccurrencesOfString:@"." withString:@""];
}
@end
