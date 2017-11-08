//
//  WQVoiceDownloaderOperation.h
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//  下载线程对象 只管下载

#import <Foundation/Foundation.h>
#import "WQVoiceDownloader.h"

static NSString * _Nonnull const WQVoiceDownFinshedNotification = @"WQVoiceDownFinshedNotification";


/**
 下载文件完成回调

 @param voiceMedia 根据WQVoiceOptions 来选择存储形式NSData 或者路径
 @param error 下载保存过程中出现的错误 (当出现错误的时候 此项一定存在)
 */
// @param finshed 是否已完成下载过程
typedef void (^WQVoiceDownloadCompleteBlock)(id  _Nullable voiceMedia ,NSURL * _Nonnull  resourceURL , NSError * _Nullable error);

@interface WQVoiceDownloadOperation : NSOperation<NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
@property (copy ,nonatomic,readonly,nonnull) NSURL *url;

-(nonnull instancetype)initWithRequest:(nonnull NSURLRequest *)request
                             inSession:(nullable NSURLSession *)session
                               options:(WQVoiceDwonloadOptions)options
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
