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

////TODO: 用于记录模型的播放状态
//@protocol WQMediaPlayStateProtocol <NSObject>
//@property (assign ,nonatomic,getter=isMediaPlaying) BOOL mediaPlaying;
///** 音频路径 */
//-(NSString *)mediaPath;
//@end
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

/** 可能有时候下载下来的是amr格式或者一些OC不支持的格式需要进行转换 */
-(instancetype)initWithCache:(WQVoiceCache *)cache downloader:(WQVoiceDownloader *)downloader;

@property (assign ,nonatomic,readonly,getter=isPlaying) BOOL playing;

/**
 当前正在播放的音频文件对应的模型 (主要用于播放异常终止而此时Block不存在或不对应的时候将模型的播放状态置为NO )
 */
//@property (strong ,nonatomic,readonly) id<WQMediaPlayStateProtocol> currentPlayMediaModel;
/**
 根据音频的模型进行音频播放
 
 @param mediaModel 音频模型
 */
//- (void)playMedia:(id<WQMediaPlayStateProtocol>)mediaModel
//        playBegin:(WQVoicePlayBeginBlock)playBeginBlock
//        playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock;

- (void)play:(NSString *)voicePath
   playBegin:(WQVoicePlayBeginBlock)playBeginBlock
   playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock;

/**
 播放音频
 
 @param voicePath 音频路径
 @param options 音频下载之后的处理选项
 @param progressBlock 音频下载过程
 @param completeBlock 完成下载语音
 @param playBeginBlock 音频开始播放回调(有可能开始失败了 开始成功了就必定会调结束的Block)
 @param playFinshedBlock 播放完成
 */
- (void)play:(NSString *)voicePath
     options:(WQVoiceOptions)options
 downProgress:(WQVoiceDownProgressBlock)progressBlock
 downComplete:(WQVoiceCacheCompleteBlock)completeBlock
    playBegin:(WQVoicePlayBeginBlock)playBeginBlock
    playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock;

//TODO: 这里语音聊天的时候 可以把模型传进来 当Block不存在的时候或者block内容不对应的时候 只将模型的播放属性置为NO
- (void)stopCurrentPlay;
@end
