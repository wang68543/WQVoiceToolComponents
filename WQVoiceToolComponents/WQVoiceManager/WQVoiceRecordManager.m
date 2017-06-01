//
//  WQVoiceRecorder.m
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import "WQVoiceRecordManager.h"
#import <AVFoundation/AVFoundation.h>
#import "amrFileCodec.h"
#import "WQVoicePlayManager.h"

@interface WQVoiceRecordManager()
@property (strong ,nonatomic) NSOperationQueue *operationQueue;
@property (nonatomic, strong) AVAudioRecorder *recorder;
@property (strong ,nonatomic) WQVoiceCache *voiceCache;
@property (copy ,nonatomic) NSString *recordKey;
/**语音格式转换*/
@property (assign ,nonatomic) WQRecordConvertStyle convertStyle;
@property (copy ,nonatomic) WQConvertRecord converRecordBlock;
@property (copy ,nonatomic) WQRecordFinshBlock stopCallback;
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
        _minRecordDuration = 2.0;
        _recordSettings = [self defaultRecordSetting];
        _operationQueue = [[NSOperationQueue alloc] init];
        _operationQueue.maxConcurrentOperationCount = 5;
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
-(NSError *)recordPathExtension:(NSString *)pathExtension metersUpdate:(WQUpdateMetersBlock)metersUpdate{
    self.metersBlock = metersUpdate;
    return [self recordWithPathExtension:pathExtension];
}
-(NSString *)defaultRecordName{
    NSString *recordName = [UIDevice currentDevice].identifierForVendor.UUIDString;
    recordName = [recordName stringByReplacingOccurrencesOfString:@"-" withString:@"" options:NSCaseInsensitiveSearch range:NSMakeRange(0, recordName.length-1)];
    recordName = [NSString stringWithFormat:@"%@%lf",recordName,[[NSDate date] timeIntervalSince1970]];
  return  [recordName stringByReplacingOccurrencesOfString:@"." withString:@""];
}
-(NSError *)recordWithPathExtension:(NSString *)pathExtension{
  return  [self recordWithName:[[self defaultRecordName] stringByAppendingPathExtension:pathExtension]];
}
-(NSError *)recordWithName:(NSString *)name{
    NSError *error;
    AVAudioSession *session = [AVAudioSession sharedInstance];
    [session setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
    if(error){
        return error;
    }
    NSString *key = [_voiceCache cacheKeyForURL:name];
    _recordKey = key;
    NSString *path = [_voiceCache defaultCachePathForKey:key];
    self.recorder = [[AVAudioRecorder alloc] initWithURL:[NSURL fileURLWithPath:path] settings:_recordSettings error:&error];
    if(error || ![self.recorder prepareToRecord]){
        if(!error){
            error = [NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"开启录音失败"}];
        }
        return error;
    }
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
        // 如果分贝不超过-20 几乎为静音
        float power = [self.recorder averagePowerForChannel:0];
        _metersBlock?_metersBlock(power):nil;
    }else{
        [self removeUpdateMetersTimer];
    }
    
}
//- (NSError *)recordWithName:(NSString *)name
//             stopedCallback:(WQRecordFinshBlock)callBack{
//    NSError *error = [self recordWithName:name];
//    _stopCallback = [callBack copy];
//    return error;
//}
-(NSData *)getRecordData{
    if(!_recordKey|| _recordKey.length <= 0 ){
            return nil;
    }
    return [NSData dataWithContentsOfFile:[_voiceCache defaultCachePathForKey:_recordKey]];
}
-(void)setConvertRecordStyle:(WQRecordConvertStyle)style{
    _convertStyle = style;
    _converRecordBlock = nil;
}
-(void)setConvertRecordOperation:(WQConvertRecord)convertOperation{
    _converRecordBlock = [convertOperation copy];
}
- (void)setUpdateMetersBlock:(WQUpdateMetersBlock)updateMeter{
    _metersBlock = [updateMeter copy];
}
-(void)addConvertRecord:(WQRecordConvertStyle)style down:(WQConvertRecordFinshed)convertFinshed{
    
     __block NSData *convertData;
    NSData *data = [self getRecordData];
    dispatch_block_t block = ^{
        switch (style) {
            case WQRecordConvertWavToAmr:
                if(data){
                   convertData = EncodeWAVEToAMR(data,1,16);
                }else{
                    convertData = nil;
                }
                break;
//            case WQRecordConvertBase64:
//                
//                break;
            case WQRecordConvertNone:
            default:
                convertData = data;
                break;
        }
    };
    NSOperation *operatio = [self addBlockOperation:block];
    [operatio setCompletionBlock:^{
        convertFinshed?convertFinshed(convertData):nil;
    }];
}

- (void)addConvertRecordOperation:(WQConvertRecord)convertOperation down:(WQConvertRecordFinshed)convertFinshed{
    NSData *data = [self getRecordData];
    if (!data){
        convertFinshed?convertFinshed(nil):nil;
        return;
    }
     __block NSData *convertData;
    NSOperation *operatio = [self addBlockOperation:^{
       convertData = convertOperation(data);
    }];
    [operatio setCompletionBlock:^{
        convertFinshed?convertFinshed(convertData):nil;
    }];
}

//-(void)stop{
//    [self stopRecord:_stopCallback];
//}
-(void)stopRecord:(WQRecordFinshBlock)recordFinsh{
    [self removeUpdateMetersTimer];
    BOOL deleteRecord = NO;
    if(self.isRecording){
        CGFloat duration = self.recorder.currentTime;
        [self.recorder stop];
        if(duration < _minRecordDuration){
            [self.recorder deleteRecording];
            if(recordFinsh){
                recordFinsh(nil,duration,[NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"录音时间太短"}]);
            }
        }else{
            NSString *recordPath = [self.recorder.url absoluteString];
            if(recordFinsh){
                deleteRecord = recordFinsh(recordPath,duration,nil);
                if(deleteRecord){
                    [self.recorder deleteRecording];
                }
            }
        }
    }else{
        if(recordFinsh){
            recordFinsh(nil,0.0,[NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"当前没有录音"}]);
        }
    }
    self.recorder = nil;
}

//-(void)post:(NSString *)path params:(NSDictionary *)params success:(HttpSuccessBlock)success failure:(HttpFailureBlock)failure{
//    __weak typeof(self) weakSelf = self;
//    if(self.converRecordBlock){
//        [self addConvertRecordOperation:self.converRecordBlock down:^(NSData *convertData) {
//             [weakSelf uploadAudioData:convertData path:path params:params success:success failure:failure];
//        }];
//    }else{
//        if(self.convertStyle == WQRecordConvertNone){
//            [self uploadAudioData:[self getRecordData] path:path params:params success:success failure:failure];
//        }else{
//            [self addConvertRecord:self.convertStyle down:^(NSData *convertData) {
//                [weakSelf uploadAudioData:convertData path:path params:params success:success failure:failure];
//            }];
//        }
//    }
//    
//}
//-(void)uploadAudioData:(NSData *)data path:(NSString *)path params:(NSDictionary *)params success:(HttpSuccessBlock)success failure:(HttpFailureBlock)failure{
//    if(!data){
//        failure?failure(nil,[NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"文件不存在"}]):nil;
//        return;
//    }
//    [WQHttpTool postAudioData:data path:path params:params progress:NULL success:success failure:failure];
//}
-(void)moveFilePathWithURL:(NSString *)urlStr{
    dispatch_block_t block = ^{
        NSString *targetKey = [_voiceCache cacheKeyForURL:urlStr];
        [[NSFileManager defaultManager] moveItemAtPath:[_voiceCache defaultCachePathForKey:_recordKey] toPath:[_voiceCache defaultCachePathForKey:targetKey] error:nil];
    };
    [self addJobToQueue:block];
}
#pragma mark --  /**外界主动打断录音*/
-(void)interruptRecord{
    if(self.isRecording){
        [self.recorder stop];
        [self.recorder deleteRecording];
    }
}
-(void)dealloc{
    if(self.recorder.isRecording){
        [self.recorder stop];
        [self.recorder deleteRecording];
    }
    NSLog(@"===录音工具销毁了");
}
@end
