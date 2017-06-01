//
//  WQVoiceDownloader.h
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//  单例全局唯一

#import <Foundation/Foundation.h>
#import "WQVoiceCache.h"

typedef NS_ENUM(NSInteger,WQConvertVoiceStyle) {
    WQConvertVoiceNone,
    WQConvertVoiceAmrToWav,
    WQConvertBase64ToWav,
    WQConvertBase64AmrToWav,
};

/**
 获取文件完成回调

 @param voiceData WQVoiceCachePolicyToDisk:此项没值 (就是当接收形式是以data形式接收的 此项才有值(此项不刻意去磁盘里面读))
 @param downURL 源文件路径
 */
typedef void (^WQVoiceCacheCompleteBlock)(NSData *voiceData,NSString *cachePath,WQVoiceCacheType cacheType,NSURL *downURL ,NSError *error);
typedef void(^WQVoiceDownProgressBlock)(NSProgress *downloadProgress);
/**
 音频格式转换(可能下载的格式iOS无法播放所以需要转换)
 
 @param downData 下载下来的原始数据
 @return 转换后的数据
 */
typedef NSData * (^WQConvertVoiceBlock)(NSData *downData);

@interface WQVoiceDownloader : NSObject
+ (instancetype)sharedVoiceDownloader;

@property (strong ,nonatomic, readonly) WQVoiceCache *voiceCache;

- (instancetype)initWithCache:(WQVoiceCache *)voiceCache;

@property (assign, nonatomic) NSTimeInterval downloadTimeout;

@property (assign ,nonatomic) NSInteger maxConcurrentDownloads;

/**
 下载过程中

 @param url 下载URL
 @param progressBlock 下载过程回调
 @param compeletedBlock 下载完成
 */
- (void)downloadWithURL:(NSURL *)url
               progress:(WQVoiceDownProgressBlock)progressBlock
              completed:(WQVoiceCacheCompleteBlock)compeletedBlock;

@property (assign ,nonatomic) WQConvertVoiceStyle convertStyle;
/**下载完成之后转换语音再播放*/
- (void)setConvertVoiceOperationBlock:(WQConvertVoiceBlock)convertOperation;

//TODO: 待实现
//// 恢复下载
//- (void)resume;
//
//// 暂停, 暂停任务, 可以恢复, 缓存没有删除
//- (void)pause;
//
//// 取消
//- (void)cancel;

// 缓存删除
//- (void)cancelAndClearCache;

- (void)cancelAllOperations;
@end
