//
//  WQVoiceManager.h
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WQVoiceCache.h"
#import "WQVoiceDownloader.h"


//TODO: 用于记录模型的播放状态
@protocol WQMediaPlayStateProtocol <NSObject>
@property (assign ,nonatomic) BOOL isMediaPlaying;
/** 音频路径 */
-(NSString *)mediaPath;
@end
/**
 音频播放完成回调

 @param error 播放出错
 @param urlStr 音频路径
 @param finshed 是否中途被打断
 */
typedef void(^WQVoicePlayFinshBlock)(NSError *error ,NSString *urlStr,BOOL finshed);
@interface WQVoicePlayManager : NSObject
+ (instancetype)manager;
@property (strong ,nonatomic, readonly) WQVoiceCache *voiceCache;

@property (strong ,nonatomic, readonly) WQVoiceDownloader *downloader;


@property (assign ,nonatomic) WQVoiceCacheType cachePocilty;

@property (assign ,nonatomic,readonly,getter=isPlaying) BOOL playing;
/** 可能有时候下载下来的是amr格式或者一些OC不支持的格式需要进行转换 */
- (instancetype)initWithCache:(WQVoiceCache *)cache downloader:(WQVoiceDownloader *)downloader;


/**
 当前正在播放的音频文件对应的模型 (主要用于播放异常终止而此时Block不存在或不对应的时候将模型的播放状态置为NO )
 */
@property (strong ,nonatomic) id<WQMediaPlayStateProtocol> currentPlayMediaModel;

/**
 根据音频的模型进行音频播放

 @param mediaModel 音频模型
 */
- (void)playMedia:(id<WQMediaPlayStateProtocol>)mediaModel
        playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock;
/**
 @param voicePath 音频路径
 */
- (void)play:(NSString *)voicePath
   playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock;

/**
 音频模型播放
 */
- (void)playMedia:(id<WQMediaPlayStateProtocol>)mediaModel
        downFinsh:(WQVoiceDowonFinshBlock)downFinshedBlock
        playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock;

/**
 播放音频

 @param voicePath 音频路径
 @param downFinshedBlock 完成下载语音
 @param playFinshedBlock 播放完成(无论如何都会走这个)
 */
- (void)play:(NSString *)voicePath
   downFinsh:(WQVoiceDowonFinshBlock)downFinshedBlock
   playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock;

//TODO: 这里语音聊天的时候 可以把模型传进来 当Block不存在的时候或者block内容不对应的时候 只将模型的播放属性置为NO
- (void)stopCurrentPlay;
@end
