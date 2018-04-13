//
//  WQVoiceRecorder.m
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import "WQVoiceRecordManager.h"
#import <AVFoundation/AVFoundation.h>

#import "WQVoicePlayManager.h"

@interface WQVoiceRecordManager()
@property (strong ,nonatomic) NSOperationQueue *operationQueue;
@property (nonatomic, strong) AVAudioRecorder *recorder;

@property (copy ,nonatomic) NSString *recordKey;
//@property (copy ,nonatomic) WQRecordFinshBlock stopCallback;
/**监测说话声音大小*/
@property (nonatomic, strong) CADisplayLink *timer;
/**声音大小回调*/
@property (copy ,nonatomic) WQUpdateMetersBlock metersBlock;

@end
@implementation WQVoiceRecordManager
+(instancetype)manager{
    //TODO: 这里如果使用静态变量 当前对象就不会释放一直存在
//    static WQVoiceRecordManager *_instance;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        _instance = [[self alloc] initWithCache:[WQVoiceCache sharedCache]];
//    });
//    return _instance;
    return [[self alloc] initWithCache:[WQVoiceCache sharedCache]];
}

-(instancetype)initWithCache:(WQVoiceCache *)cache{
    if(self = [super init]){
        _voiceCache = cache;
//        _minRecordDuration = 2.0;
        _recordSettings = [self defaultRecordSetting];
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 2;
        _conversionTool = [WQVoiceConversionTool manager];
//        _convertStyle = WQConvertVoiceNone;
    }
    return self;
}

-(void)addJobToQueue:(void (^)(void))block{
    [self.operationQueue addOperationWithBlock:block];
}
-(NSOperation *)addBlockOperation:(dispatch_block_t)block{
    NSOperation *operation = [NSBlockOperation blockOperationWithBlock:block];
    [self.operationQueue addOperation:operation];
    return operation;
}
-(BOOL)isRecording{
    return self.recorder&& self.recorder.isRecording;
}
/**默认的录音设置*/
- (NSDictionary*)defaultRecordSetting{
    NSDictionary *recordSetting = [[NSDictionary alloc] initWithObjectsAndKeys:
                                   [NSNumber numberWithFloat: 8000.0],AVSampleRateKey, //采样率
                                   [NSNumber numberWithInt: kAudioFormatLinearPCM],AVFormatIDKey,
                                   [NSNumber numberWithInt:16],AVLinearPCMBitDepthKey,//采样位数 默认 16
                                   [NSNumber numberWithInt: 1], AVNumberOfChannelsKey,//通道的数目
                                   //                                   [NSNumber numberWithBool:NO],AVLinearPCMIsBigEndianKey,//大端还是小端 是内存的组织方式
                                   //                                   [NSNumber numberWithBool:NO],AVLinearPCMIsFloatKey,//采样信号是整数还是浮点数
                                   //                                   [NSNumber numberWithInt: AVAudioQualityMedium],AVEncoderAudioQualityKey,//音频编码质量
                                   nil];
    return recordSetting;
}

//MARK: =========== 指定录音路径 ===========
- (NSError *)recordWithPath:(NSString *)recordPath{
    return [self record:recordPath recordSettings:[self defaultRecordSetting] metersUpdate:nil];
}

-(NSError *)record:(NSString *)recordPath recordSettings:(NSDictionary *)recordSettings metersUpdate:(WQUpdateMetersBlock)metersUpdate{
    NSAssert(recordPath != nil, @"录音存储路径不能为空");
    NSError *error;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if(error){
        return error;
    }
    
    self.recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:recordPath] settings:recordSettings error:&error];
    _recordSettings = recordSettings;
    if(error || ![self.recorder prepareToRecord]){
        if(!error){
            error = [NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"开启录音失败"}];
        }
        return error;
    }
    
    
    _metersBlock = metersUpdate;
    // 开启分贝测量功能
    if(_metersBlock){
        self.recorder.meteringEnabled = YES;
        [self addUpdateMetersTimer];
    }
    [self.recorder record];
    
    return nil;
}

- (void)addUpdateMetersTimer{
    self.timer = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateRecordMeters)];
    [self.timer addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
}

- (void)removeUpdateMetersTimer{
    if(self.timer){
        [self.timer invalidate];
        self.timer = nil;
    }
}

- (void)updateRecordMeters{
    if(self.isRecording){
        [self.recorder updateMeters];
        // 如果分贝不超过-20 几乎为静音 peakPowerForChannel:音量的最大值
        double power = [self.recorder averagePowerForChannel:0];
//        double power = pow(10, [self.recorder averagePowerForChannel:0]*0.05);//使得power的取值范围是0~1
        _metersBlock?_metersBlock(power):nil;
    }else{
        [self removeUpdateMetersTimer];
    }
    
}

- (void)cancelRecord{
    [self removeUpdateMetersTimer];
    if(self.isRecording){
        [self.recorder stop];
        [self.recorder deleteRecording];
    }
}

-(void)stopRecord:(WQRecordFinshBlock)recordFinsh{
    [self removeUpdateMetersTimer];
    CGFloat duration = 0.0;
    NSError *error;
    NSString *recordPath =  [self _stopRecord:&duration error:&error];
    if(recordFinsh){
        recordFinsh(recordPath,duration,error);
    }
  
}
-(void)stopRecordToConversion:(WQConvertVoiceStyle)style compeletion:(WQStopFinshConvert)compeletion{
    CGFloat duration;
    NSError *error;
    NSString *recordPath =  [self _stopRecord:&duration error:&error];
    if (recordPath && !error && compeletion) {
        [self.conversionTool voiceConversion:style from:recordPath targetPath:nil compeletion:^(NSError *error, id conversionMedia) {
            compeletion(recordPath,conversionMedia,duration,error);
        }];
    }else{
        if (compeletion) {
            compeletion(recordPath,nil,0.0,error);
        }
    }
}

//MARK: =========== 私有方法 停止录音 ===========
-(NSString *)_stopRecord:(CGFloat *)duration error:(NSError * *)error{
    [self removeUpdateMetersTimer];
    NSString *recordPath;
    if(self.isRecording){
        *duration = self.recorder.currentTime;
        recordPath = self.recorder.url.path;
        [self.recorder stop];
    }else{
        *error = [NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"当前没有录音"}];
    }
    self.recorder = nil;
    return recordPath;
}

-(void)dealloc{
    if(self.recorder.isRecording){
        [self.recorder stop];
        [self.recorder deleteRecording];
    }
    NSLog(@"===录音工具销毁了");
}

@end
