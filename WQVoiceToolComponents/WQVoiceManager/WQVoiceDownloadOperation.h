//
//  WQVoiceDownloaderOperation.h
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WQVoiceDownloader.h"

static NSString * _Nonnull const WQVoiceDownFinshedNotification = @"WQVoiceDownFinshedNotification";


/**
 下载文件完成回调

 @param voiceData WQVoiceCachePolicyToDisk:此项没值 (就是当接收形式是以data形式接收的 此项才有值(此项不刻意去磁盘里面读))
 @param voicePath WQVoiceCachePolicyNone 此项没值
 @param error 下载保存过程中出现的错误 (当出现错误的时候 此项一定存在)
 @param finshed 是否已完成下载过程
 */
typedef void (^WQVoiceDownloadCompleteBlock)(NSData * _Nullable voiceData , NSString * _Nullable voicePath, NSError * _Nullable error ,BOOL finshed);

@interface WQVoiceDownloadOperation : NSOperation<NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
@property (copy ,nonatomic,readonly,nonnull) NSURL *url;

- (void)setConvertVoiceOperationBlock:(nonnull WQConvertVoiceBlock)convertOperation;

@property (assign ,nonatomic) WQConvertVoiceStyle convertStyle;

/** 缓存对象 此处用于管理缓存路径 */
@property (strong ,nonatomic,nullable) WQVoiceCache *voiceCache;


-(nonnull instancetype)initWithRequest:(nonnull NSURLRequest *)request
                             inSession:(nullable NSURLSession *)session
                               options:(WQVoiceOptions)options
                              progress:(nullable WQVoiceDownProgressBlock)progressBlock
                              complete:(nullable WQVoiceDownloadCompleteBlock)completeBlock
                           cancelBlock:(nonnull dispatch_block_t)cancelBlock;
//TODO: 采用session下载
/** 请求对象 */
@property (strong, nonatomic, readonly,nonnull) NSURLRequest *request;

/** 当前线程的task */
@property (strong, nonatomic, readonly ,nonnull) NSURLSessionTask *dataTask;
/** 文件的下载进度 */
@property (strong ,nonatomic ,readonly ,nonnull ) NSProgress *downloadProgress;
@end
