//
//  WQVoiceManager.h
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//  主要用于小音频播放

#import <Foundation/Foundation.h>
#import "WQVoiceCache.h"
#import "WQVoiceDownloader.h"


/**
 获取音频完成回调

 @param voiceMedia 音频资源(path 或 NSData)
 @param cacheType 音频来源
 @param downloadURL 音频资源地址
 @param error 未获取到音频的原因
 */
typedef void (^WQVoiceCacheCompleteBlock)(id voiceMedia,WQVoiceCacheType cacheType,NSURL *downloadURL ,NSError *error);

/**
 音频播放完成回调

 @param error 播放出错
 @param url 音频路径
 @param finshed 是否中途被打断
 */
typedef void(^WQVoicePlayFinshBlock)(NSError *error ,NSURL *url,BOOL finshed);

/**
 音频开始播放回调

 @param error 播放过程中出错
 */
typedef void(^WQVoicePlayBeginBlock)(NSError *error ,NSURL *url);

@interface WQVoicePlayManager : NSObject
+ (instancetype)manager;
@property (strong ,nonatomic, readonly) WQVoiceCache *voiceCache;

@property (strong ,nonatomic, readonly) WQVoiceDownloader *downloader;
/** 允许后台播放 默认 YES */
@property (assign  ,nonatomic) BOOL allowPlayInBackground;

/** 可能有时候下载下来的是amr格式或者一些OC不支持的格式需要进行转换 */
-(instancetype)initWithCache:(WQVoiceCache *)cache downloader:(WQVoiceDownloader *)downloader;

@property (assign ,nonatomic,readonly,getter=isPlaying) BOOL playing;

//
- (void)play:(NSString *)voicePath
downComplete:(WQVoiceCacheCompleteBlock)completeBlock
   playBegin:(WQVoicePlayBeginBlock)playBeginBlock
   playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock;

/**
 播放音频
 
 @param voicePath 音频路径
 @param progressBlock 音频下载过程
 @param completeBlock 完成下载语音
 @param playBeginBlock 音频开始播放回调 (语音获取成功之后才会有开始回调)
 @param playFinshedBlock 播放完成 (播放成功之后才会会回调播放完成,中间打断了会先回调)
 */
- (void)play:(NSString *)voicePath
 downProgress:(WQVoiceDownProgressBlock)progressBlock
 downComplete:(WQVoiceCacheCompleteBlock)completeBlock
    playBegin:(WQVoicePlayBeginBlock)playBeginBlock
    playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock;

//TODO: 这里语音聊天的时候 可以把模型传进来 当Block不存在的时候或者block内容不对应的时候 只将模型的播放属性置为NO
// 会回调播放完成回调(如果当前正在播放的话)
- (void)stopCurrentPlay;
@end
