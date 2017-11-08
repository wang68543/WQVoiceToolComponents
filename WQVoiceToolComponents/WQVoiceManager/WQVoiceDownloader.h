//
//  WQVoiceDownloader.h
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//  管理文件下载、缓存、以及从缓存中读取文件

#import <Foundation/Foundation.h>
#import "WQVoiceCache.h"
#import "WQVoiceConversionTool.h"


// 默认都会存储到磁盘上
typedef NS_ENUM (NSUInteger ,WQVoiceDwonloadOptions){
//    WQVoiceCacheMemoryOnly = 1 << 0,//只加载到内存中
//    WQVoiceRefreshCached  = 1 << 1,//刷新缓存
//    WQVoiceDownloadCacheInStream  = 1 << 2,//以流的形式存储文件不加载到内存
//    WQVoiceDownloadCacheInData  = 1 << 3, //加载到内存里面 以Data形式写入到文件
//    WQVoiceDownloadContinueInBackground  = 1 << 4,//后台继续下载
    WQVoiceDownloadCacheInData   ,//默认
    WQVoiceDownloadCacheInStream  ,
    WQVoiceDownloadContinueInBackground  ,
    
    //    WQVoicePlayContinueInBackground,//后台继续播放
} ;

typedef void (^WQVoiceDownCompleteBlock) (id voiceMedia , NSURL *downURL , NSError *error);
typedef void(^WQVoiceDownProgressBlock)(NSProgress *downloadProgress);

@interface WQVoiceDownloader : NSObject
+ (instancetype)sharedVoiceDownloader;

@property (strong ,nonatomic, readonly) WQVoiceCache *voiceCache;

- (instancetype)initWithCache:(WQVoiceCache *)voiceCache;
/** 下载响应超时时间 默认15s */
@property (assign, nonatomic) NSTimeInterval downloadTimeout;

/** 最大并发下载数量 默认5 */
@property (assign ,nonatomic) NSInteger maxConcurrentDownloads;
/** 是否需要缓存 默认YES */
@property (assign  ,nonatomic) BOOL shouldCache;

//MARK: =========== 下载之后的音频格式转换 ===========
/** 固定几种类型的语音转换 */
@property (assign ,nonatomic) WQConvertVoiceStyle convertStyle;
/** 自定义音频格式转换 */
@property (copy    ,nonatomic) WQConvertVoiceBlock conversionOperation;

/**
 下载过程中

 @param url 下载URL
 @param progressBlock 下载过程回调
 @param compeletedBlock 下载完成
 */
- (void)downloadWithURL:(NSURL *)url
               progress:(WQVoiceDownProgressBlock)progressBlock
              completed:(WQVoiceDownCompleteBlock)compeletedBlock;

- (void)downloadWithURL:(NSURL *)url
                options:(WQVoiceDwonloadOptions)options
               progress:(WQVoiceDownProgressBlock)progressBlock
              completed:(WQVoiceDownCompleteBlock)compeletedBlock;


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
