//
//  WQVoiceManager.m
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import "WQVoicePlayManager.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import "WQVoiceCache.h"

@interface WQVoicePlayManager()<AVAudioPlayerDelegate>
@property (strong ,nonatomic) AVAudioPlayer *player;

@property (copy ,nonatomic) WQVoicePlayFinshBlock playFinshed;

@property (copy ,nonatomic) WQVoicePlayBeginBlock playBegin;

@property (copy ,nonatomic) NSURL *currentURL;

/** 旧的播放模型 */
//@property (strong ,nonatomic) id<WQMediaPlayStateProtocol> oldPlayMediaModel;

@end
@implementation WQVoicePlayManager
static WQVoicePlayManager *_instance;
+(instancetype)manager{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
//        WQVoiceCache *voiceCache = [[WQVoiceCache alloc] initWithNamespace:NSStringFromClass([self class])];
        WQVoiceCache *voiceCache = [WQVoiceCache sharedCache];
        _instance = [[self alloc] initWithCache:voiceCache downloader:[[WQVoiceDownloader alloc] initWithCache:voiceCache]];
    });
    return _instance;
}
- (void)appDidEnterBackground{
    [self stopCurrentPlay];
}
-(instancetype)initWithCache:(WQVoiceCache *)cache downloader:(WQVoiceDownloader *)downloader{
    if(self = [super init]){
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        _voiceCache = cache;
        _downloader = downloader;
    }
    return self;
}
-(BOOL)isPlaying{
    return self.player && self.player.isPlaying;
}
-(void)stopCurrentPlay{
    if(self.isPlaying){
        [self.player stop];
        _playFinshed? _playFinshed(nil,_currentURL,NO):nil;
    }
    [self playFinshReset:NO];
//    [self stopCurrentPlayWithModel:self.currentPlayMediaModel];
}

#pragma mark -- 私有方法

-(void)playWithData:(NSData *)data{
     //当存在回调block的时候 下载完了监测下block是否存在 如果还存在就播放否则就不播放
    
     NSError *error;
    do {
        self.player = [[AVAudioPlayer alloc] initWithData:data error:&error];
        if(error) break;
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
        if(error) break;
        if([self.player prepareToPlay]){
            if(![self.player play]){
               error = [NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"播放失败"}];
                 [self.player stop];
            }
        }else{
             error = [NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"准备播放失败"}];
        }
    } while (NO);
   
    if(error){
         _playBegin ? _playBegin(error,_currentURL):nil;
        
        //此处结束了 不回调finshBlock
        [self playFinshReset:NO];
    }else{
//        if(self.currentPlayMediaModel){
//            [self.currentPlayMediaModel setMediaPlaying:YES];
//        }
       self.player.delegate = self;
      _playBegin ? _playBegin(nil,_currentURL):nil;
    }
   
}
//播放打断
- (void)interruptPlaying{
    if(self.isPlaying){
        [self.player stop];
        _playFinshed? _playFinshed([NSError errorWithDomain:WQVoiceErrorDomain code:-1 userInfo:@{NSLocalizedDescriptionKey:@"interrupt error"}],_currentURL,NO):nil;
    }
    [self playFinshReset:NO];
}
//-(void)stopCurrentPlayWithModel:(id<WQMediaPlayStateProtocol>)model{
//    if(self.isPlaying){
//        [self.player stop];
//    }
//    if(model){
//        [model setMediaPlaying:NO];
//    }
//    //中途被打断
//    [self playFinshReset:NO];
//}

-(void)playFinshReset:(BOOL)finshed{
    _playBegin = nil;
    _playFinshed = nil;
    _player = nil;
    _currentURL = nil;
//    _oldPlayMediaModel = nil;
}

#pragma mark -- 私有方法End

//-(void)playMedia:(id<WQMediaPlayStateProtocol>)mediaModel playBegin:(WQVoicePlayBeginBlock)playBeginBlock playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock{
//    _currentPlayMediaModel = mediaModel;
//    [self play:[mediaModel mediaPath] playBegin:playBeginBlock playFinsh:playFinshedBlock];
//}
-(void)play:(NSString *)voicePath playBegin:(WQVoicePlayBeginBlock)playBeginBlock playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock{
    [self play:voicePath options:WQVoiceDownloadCacheInData downProgress:NULL downComplete:NULL playBegin:playBeginBlock playFinsh:playFinshedBlock];
}

//TODO: 语音播放 1.停止当前正在播放的 2.下载或缓存中取音频文件 3.取到文件当存在block的时候开始播放 没取到文件的时候直接调下载完成block然后调播放完成的block 4.正常播放回调播放完成block
-(void)play:(NSString *)voicePath options:(WQVoiceOptions)options downProgress:(WQVoiceDownProgressBlock)progressBlock downComplete:(WQVoiceCacheCompleteBlock)completeBlock playBegin:(WQVoicePlayBeginBlock)playBeginBlock playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock{
    [self interruptPlaying];
    
    NSString *key = [_voiceCache cacheKeyForURL:voicePath];
    //不存在key的时候就
    if(key.length <= 0){
        playFinshedBlock?playFinshedBlock([NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"音频路径不存在"}],nil,YES):nil;
    }
    
    __weak typeof(self) weakSelf = self;
    
   
    self.playBegin = playBeginBlock;
    self.playFinshed  = playFinshedBlock;
    
    
    __weak  NSURL *voiceURL = [NSURL URLWithString:voicePath];
     self.currentURL = voiceURL;
    [self.voiceCache queryVoiceCacheForKey:key done:^(NSString *voicePath, WQVoiceCacheType cacheType) {
        NSData *voiceData = [self audioDataWithPath:voicePath];
        if(voiceData){
            //读取文件完成回调
            completeBlock?completeBlock(voiceData,voicePath,cacheType,voiceURL,nil):nil;
            [weakSelf playWithData:voiceData];
        }else{
            [weakSelf.downloader downloadWithURL:voiceURL progress:progressBlock completed:^(NSData *voiceData ,NSString *cachePath, WQVoiceCacheType cacheType, NSURL *url, NSError *error) {
                if(voiceData){
                    //下载完成
                    completeBlock?completeBlock(voiceData,cachePath,cacheType,url,nil):nil;
                   [weakSelf playWithData:voiceData];
                }else{
                    
                    if(!error){
                        error = [NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"radio download failed!"}];
                    }
                    //下载完成
                    completeBlock?completeBlock(voiceData,cachePath,cacheType,url,error):nil;
                    weakSelf.playBegin = nil;
                    weakSelf.playFinshed = nil;
                    weakSelf.currentURL = nil;
                }
            }];
        }
    }];
}
#pragma mark -- 私有方法
#pragma mark -- -根据路劲读取语音
- (NSData *)audioDataWithPath:(NSString *)audioPath{
    if(!audioPath || audioPath.length <= 0) return nil;
   return  [NSData dataWithContentsOfFile:audioPath];
}
#pragma mark -- AVAudioPlayerDelegate
-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    _playFinshed ? _playFinshed(nil,_currentURL,flag):nil;
    [self playFinshReset:YES];
}
-(void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error{

    _playFinshed ? _playFinshed(error,_currentURL,YES):nil;
     [self playFinshReset:YES];
}

- (void)dealloc{
    if(self.isPlaying){
        [self.player stop];
    }
    _playBegin = nil;
    _playFinshed = nil;
}
@end
