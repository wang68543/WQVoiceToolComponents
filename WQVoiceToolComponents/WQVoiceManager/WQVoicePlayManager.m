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

-(instancetype)initWithCache:(WQVoiceCache *)cache downloader:(WQVoiceDownloader *)downloader{
    if(self = [super init]){
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appDidEnterBackground) name:UIApplicationDidEnterBackgroundNotification object:nil];
        _voiceCache = cache;
        _downloader = downloader;
        _allowPlayInBackground = YES;
    }
    return self;
}
//MARK: =========== app进入后台 ===========
- (void)appDidEnterBackground{
    if (!self.allowPlayInBackground) {
       [self stopCurrentPlay];
    }
}
-(BOOL)isPlaying{
    return self.player && self.player.isPlaying;
}
-(void)stopCurrentPlay{
    if(self.isPlaying){
        [self.player stop];
        _playFinshed? _playFinshed(nil,_currentURL,NO):nil;
    }
    [self _playFinshReset:NO];
}

#pragma mark -- 私有方法

-(void)_playWithVoiceMedia:(id)voiceMedia{
     //当存在回调block的时候 下载完了监测下block是否存在 如果还存在就播放否则就不播放
    
     NSError *error;
    do {
        if ([voiceMedia isKindOfClass:[NSData class]]) {
             self.player = [[AVAudioPlayer alloc] initWithData:voiceMedia error:&error];
        }else{
             self.player = [[AVAudioPlayer alloc] initWithData:[NSData dataWithContentsOfFile:voiceMedia] error:&error];
        }
       
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
        [self _playFinshReset:NO];
    }else{
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
    [self _playFinshReset:NO];
}


-(void)_playFinshReset:(BOOL)finshed{
    _playBegin = nil;
    _playFinshed = nil;
    _player = nil;
    _currentURL = nil;
//    _oldPlayMediaModel = nil;
}

#pragma mark -- 私有方法End
-(void)play:(NSString *)voicePath downComplete:(WQVoiceCacheCompleteBlock)completeBlock playBegin:(WQVoicePlayBeginBlock)playBeginBlock playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock{
    [self play:voicePath downProgress:NULL downComplete:completeBlock playBegin:playBeginBlock playFinsh:playFinshedBlock];
}

//TODO: 语音播放 1.停止当前正在播放的 2.下载或缓存中取音频文件 3.取到文件当存在block的时候开始播放 没取到文件的时候直接调下载完成block然后调播放完成的block 4.正常播放回调播放完成block
-(void)play:(NSString *)voicePath downProgress:(WQVoiceDownProgressBlock)progressBlock downComplete:(WQVoiceCacheCompleteBlock)completeBlock playBegin:(WQVoicePlayBeginBlock)playBeginBlock playFinsh:(WQVoicePlayFinshBlock)playFinshedBlock{
    [self interruptPlaying];
    
    NSURL *voiceURL = [NSURL URLWithString:voicePath];

    if(!voiceURL){
        NSError *error = [NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey : @"音频路径不存在"}];
         completeBlock?completeBlock(nil,WQVoiceCacheTypeNone,voiceURL,error):nil;
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    self.playBegin = playBeginBlock;
    self.playFinshed  = playFinshedBlock;

    self.currentURL = voiceURL;
    [self.voiceCache queryVoiceCacheForURL:voiceURL done:^(NSString *cachePath, WQVoiceCacheType cacheType) {
        if (cachePath) {
            completeBlock?completeBlock(cachePath,cacheType,voiceURL,nil):nil;
            [weakSelf _playWithVoiceMedia:cachePath];
        }else{
            [weakSelf.downloader downloadWithURL:voiceURL progress:progressBlock completed:^(id voiceMedia, NSURL *downURL, NSError *error) {
                if (voiceMedia) {
                    completeBlock?completeBlock(voiceMedia,WQVoiceCacheTypeNone,downURL,error):nil;
                    [weakSelf _playWithVoiceMedia:voiceMedia];
                }else{
                    if(!error){
                        error = [NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"radio download failed!"}];
                    }
                    completeBlock?completeBlock(voiceMedia,WQVoiceCacheTypeNone,downURL,error):nil;
                    weakSelf.playBegin = nil;
                    weakSelf.playFinshed = nil;
                    weakSelf.currentURL = nil;
                }
            }];
        }
    }];
 
}
#pragma mark -- 私有方法
#pragma mark -- AVAudioPlayerDelegate
-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag{
    _playFinshed ? _playFinshed(nil,_currentURL,flag):nil;
    [self _playFinshReset:YES];
}
-(void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error{

    _playFinshed ? _playFinshed(error,_currentURL,YES):nil;
     [self _playFinshReset:YES];
}

- (void)dealloc{
    if(self.isPlaying){
        [self.player stop];
    }
    _playBegin = nil;
    _playFinshed = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
