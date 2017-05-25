//
//  WQVoiceDownloader.m
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import "WQVoiceDownloader.h"
#import "WQVoiceDownloadOperation.h"
@interface WQVoiceDownloader()
@property (strong ,nonatomic) NSOperationQueue *downloadQueue;
/** key:url value:operation对象 */
@property (nonatomic, strong) NSMutableDictionary *downloadOperations;

@property (copy ,nonatomic) WQConvertVoiceBlock convertVoiceOperation;
@property (assign ,nonatomic) WQConvertVoiceStyle convertVoiceStyle;
@end
@implementation WQVoiceDownloader
static WQVoiceDownloader *_instance;
+(instancetype)sharedVoiceDownloader{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] init];
    });
    return _instance;
}
+(instancetype)allocWithZone:(struct _NSZone *)zone{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _instance = [super allocWithZone:zone];
    });
    return _instance;
}
- (instancetype)copyWithZone:(NSZone *)zone{
    return _instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.maxConcurrentOperationCount = 5;
        _downloadOperations = [NSMutableDictionary dictionary];
        _convertVoiceStyle = WQConvertVoiceNone;
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(voiceDownFinshed:) name:WQVoiceDownFinshedNotification object:nil];
    }
    return self;
}
- (void)voiceDownFinshed:(NSNotification *)notification{
    WQVoiceDownloadOperation *operation = notification.object;
    [self.downloadOperations removeObjectForKey:[operation.url absoluteString]];
}
//TODO:以Block的形式添加任务到队列中
-(void)addJobToQueue:(void (^)(void))block{
    [self.downloadQueue addOperationWithBlock:block];
}
- (void)setConvertVoiceStyle:(WQConvertVoiceStyle)style{
    _convertVoiceStyle = style;
    _convertVoiceOperation = nil;
}
- (void)setConvertWithBlock:(WQConvertVoiceBlock)block{
    _convertVoiceOperation = block;
}
- (void)setMaxConcurrentDownloads:(NSInteger)maxConcurrentDownloads{
    _downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads;
}
-(void)downloadVoiceWithURL:(NSURL *)url completed:(WQVoiceDowonFinshBlock)compeletedBlock{
    if(!url || [url absoluteString].length <= 0){
        compeletedBlock? compeletedBlock(nil,WQVoiceCacheTypeNone,@"",[NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"路径为空"}]): nil;
        return;
    }
    WQVoiceDownloadOperation *operation;
    operation = _downloadOperations[url.absoluteString];
    if(!operation){
       operation = [[WQVoiceDownloadOperation alloc] initWithURL:url convertStyle:self.convertVoiceStyle convertBlock:self.convertVoiceOperation compelete:compeletedBlock];
        [self.downloadQueue addOperation:operation];
        @synchronized (_downloadQueue) {
          _downloadOperations[url.absoluteString] = operation;  
        }
        
    }
    
}
-(void)cancelAllOperations{
    [self.downloadQueue cancelAllOperations];
    [self.downloadOperations removeAllObjects];
}

-(void)dealloc{
    [self cancelAllOperations];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
