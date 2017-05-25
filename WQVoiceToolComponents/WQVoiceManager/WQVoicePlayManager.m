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
@property (copy ,nonatomic) NSString *currentURL;

@end
@implementation WQVoicePlayManager
static WQVoicePlayManager *_instance;
+(instancetype)manager{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] initWithCache:[WQVoiceCache sharedCache] downloader:[WQVoiceDownloader sharedVoiceDownloader]];
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
        _cachePocilty = WQVoiceCacheTypeDisk;
    }
    return self;
}
-(BOOL)isPlaying{
    return self.player && self.player.isPlaying;
}

-(void)stopCurrentPlay{
    if(self.isPlaying){
        [self.player stop];
        self.currentPlayMediaModel.isMediaPlaying = NO;
        //中途被打断
        _playFinshed ? _playFinshed(nil,_currentURL,NO):nil;
        _playFinshed = nil;
        self.player = nil;
        _currentURL = nil;
    }
}
-(void)playWithData:(NSData *)data{
     NSError *error;
    do {
        self.player = [[AVAudioPlayer alloc] initWithData:data error:&error];
        if(error) break;
        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayback error:&error];
        if(error) break;
        if(![self.player prepareToPlay] || ![self.player play]){
            error = [NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"播放失败"}];
        }
    } while (NO);
    if(error){
        _playFinshed ? _playFinshed(error,_currentURL,YES):nil;
        _currentURL = nil;
        _player = nil;
        _playFinshed = nil;
    }else{
        if(self.currentPlayMediaModel){
            self.currentPlayMediaModel.isMediaPlaying = YES;
        }
       self.player.delegate = self;
    }
}
- (void)playMedia:(id<WQMediaPlayStateProtocol>)mediaModel playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock{
    [self playMedia:mediaModel downFinsh:NULL playFinsh:playFinshedBlock];
}
-(void)playMedia:(id<WQMediaPlayStateProtocol>)mediaModel downFinsh:(WQVoiceDowonFinshBlock)downFinshedBlock playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock{
    [self play:[mediaModel mediaPath] downFinsh:downFinshedBlock playFinsh:playFinshedBlock];
    self.currentPlayMediaModel = mediaModel;
}
- (void)play:(NSString *)voicePath
   playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock{
    [self play:voicePath downFinsh:nil playFinsh:playFinshedBlock];
}


//TODO: 语音播放 1.停止当前正在播放的 2.下载或缓存中取音频文件 3.取到文件当存在block的时候开始播放 没取到文件的时候直接调下载完成block然后调播放完成的block 4.正常播放回调播放完成block
-(void)play:(NSString *)voicePath downFinsh:(WQVoiceDowonFinshBlock)downFinshedBlock playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock{
    [self stopCurrentPlay];//这里停止播放对旧的模型以及旧的block进行回调 在这之后再进行模型和block重新赋值
    
    NSString *key = [_voiceCache cacheKeyForURL:voicePath];
    //不存在key的时候就
    if(key.length <= 0){
        playFinshedBlock?playFinshedBlock([NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"音频路径不存在"}],voicePath,YES):nil;
    }
    __weak typeof(self) weakSelf = self;
    
    //当存在回调block的时候 下载完了监测下block是否存在 如果还存在就播放否则就不播放
   __block  BOOL isNeedCheckToPlay ;
    if(playFinshedBlock){
        isNeedCheckToPlay = YES;
    }else{
        isNeedCheckToPlay = NO;
    }
    [_voiceCache queryVoiceCacheForKey:key done:^(NSData *voiceData, WQVoiceCacheType cacheType) {
        if(voiceData){
            if(isNeedCheckToPlay){
                if(playFinshedBlock){
                    [weakSelf playWithData:voiceData];
                }
            }else{
                [weakSelf playWithData:voiceData];
            }
            downFinshedBlock?downFinshedBlock(voiceData,cacheType,voicePath,nil):nil;
//             [weakSelf stopCurrentPlay];
            _currentURL = voicePath;
            _playFinshed = [playFinshedBlock copy];
        }else{
            [_downloader downloadVoiceWithURL:[NSURL URLWithString:voicePath] completed:^(NSData *voiceData, WQVoiceCacheType cacheType, NSString *urlStr, NSError *error) {
                if(voiceData){
                    if(isNeedCheckToPlay){
                        if(playFinshedBlock){
                            [weakSelf playWithData:voiceData];
                        }
                    }else{
                        [weakSelf playWithData:voiceData];
                    }
                  downFinshedBlock?downFinshedBlock(voiceData,cacheType,urlStr,nil):nil;
//                    [weakSelf stopCurrentPlay];
                    _currentURL = urlStr;
                    _playFinshed = [playFinshedBlock copy];
                    [weakSelf.voiceCache storeVoice:voiceData forKey:key];
                }else{
                    
                   downFinshedBlock?downFinshedBlock(voiceData,cacheType,urlStr,error):nil;
//                    [weakSelf stopCurrentPlay];
                    _playFinshed = nil;
                    playFinshedBlock?playFinshedBlock(error,urlStr,YES):nil;
                }
            }];
        }
    }];
}

#pragma mark -- AVAudioPlayerDelegate
-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    _playFinshed ? _playFinshed(nil,_currentURL,flag):nil;
    _player = nil;
}
-(void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error{
    _playFinshed ? _playFinshed(error,_currentURL,YES):nil;
    _player = nil;
}
- (void)dealloc{
    if(self.isPlaying){
        [self.player stop];
    }
    NSLog(@"===播放工具销毁了");
}
@end
