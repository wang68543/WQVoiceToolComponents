//
//  WQVoiceDownloader.m
//  SomeUIKit
//
//  Created by WangQiang on 2017/4/14.
//  Copyright © 2017年 WangQiang. All rights reserved.
//

#import "WQVoiceDownloader.h"
#import "WQVoiceDownloadOperation.h"

static NSString *const kProgressCallbackKey = @"progress";
static NSString *const kCompletedCallbackKey = @"completed";

@interface WQVoiceDownloader()<NSURLSessionTaskDelegate, NSURLSessionDataDelegate>
@property (strong ,nonatomic) NSOperationQueue *downloadQueue;
@property (copy ,nonatomic) WQConvertVoiceBlock convertVoiceOperation;

@property (strong, nonatomic) NSURLSession *session;

/** 回调的Block保存 (也可以防重复) */
@property (strong, nonatomic) NSMutableDictionary *URLCallbacks;
@property (strong, nonatomic) NSMutableDictionary *HTTPHeaders;
// This queue is used to serialize the handling of the network responses of all the download operation in a single queue
@property (strong, nonatomic) dispatch_queue_t barrierQueue;
//@property (strong ,nonatomic) WQVoiceCache *voiceCache;

@property (strong  ,nonatomic) WQVoiceConversionTool *conversionTool;
@end
@implementation WQVoiceDownloader

+(instancetype)sharedVoiceDownloader{
    static dispatch_once_t onceToken;
    static WQVoiceDownloader *_instance;
    dispatch_once(&onceToken, ^{
        _instance = [[self alloc] initWithCache:[WQVoiceCache sharedCache]];
    });
    return _instance;
}
-(WQVoiceConversionTool *)conversionTool{
    if (!_conversionTool) {
        _conversionTool = [WQVoiceConversionTool manager];
    }
    return _conversionTool;
}

-(instancetype)initWithCache:(WQVoiceCache *)voiceCache{
    self = [super init];
    if (self) {
        _downloadQueue = [[NSOperationQueue alloc] init];
        _downloadQueue.maxConcurrentOperationCount = 5;
//        _convertStyle = WQConvertVoiceNone;
        
        _downloadTimeout = 15.0;
        _voiceCache = voiceCache;
        
        _shouldCache = YES;
        
        _URLCallbacks = [NSMutableDictionary new];
        _barrierQueue = dispatch_queue_create("com.WQVoiceDownloadBarrierQueue", DISPATCH_QUEUE_CONCURRENT);
        NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
        sessionConfig.timeoutIntervalForRequest = _downloadTimeout;
        
        /**
         *  Create the session for this task
         *  We send nil as delegate queue so that the session creates a serial operation queue for performing all delegate
         *  method calls and completion handler calls.
         */
        self.session = [NSURLSession sessionWithConfiguration:sessionConfig
                                                     delegate:self
                                                delegateQueue:nil];
        //        _voiceCache = [WQVoiceCache sharedCache];
        
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(voiceDownFinshed:) name:WQVoiceDownFinshedNotification object:nil];
        
    }
    return self;
}
- (void)voiceDownFinshed:(NSNotification *)notification{
//    WQVoiceDownloadOperation *operation = notification.object;
//    [self.downloadQueue.operations removeObserver:<#(nonnull NSObject *)#> forKeyPath:<#(nonnull NSString *)#>];
}
//-(void)setConvertStyle:(WQConvertVoiceStyle)convertStyle{
//    _convertStyle = convertStyle;
//    if(convertStyle != WQConvertVoiceNone){
//      _convertVoiceOperation = nil;
//    }
//}
- (void)setMaxConcurrentDownloads:(NSInteger)maxConcurrentDownloads{
    _downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads;
}

-(void)downloadWithURL:(NSURL *)url progress:(WQVoiceDownProgressBlock)progressBlock completed:(WQVoiceDownCompleteBlock)compeletedBlock{
    [self downloadWithURL:url options:WQVoiceDownloadCacheInData progress:progressBlock completed:compeletedBlock];
}
-(void)downloadWithURL:(NSURL *)url options:(WQVoiceDwonloadOptions)options progress:(WQVoiceDownProgressBlock)progressBlock completed:(WQVoiceDownCompleteBlock)compeletedBlock{
    __block  WQVoiceDownloadOperation *operation;
    __weak __typeof(self)wself = self;
    [self addProgressCallback:progressBlock completedBlock:compeletedBlock forURL:url createCallback:^{
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:wself.downloadTimeout];
        
        operation = [[WQVoiceDownloadOperation alloc] initWithRequest:request inSession:self.session options:options progress:^(NSProgress *downloadProgress) {
            WQVoiceDownloader *sself = wself;
            if (!sself) return;
            __block NSDictionary *callbacksForURL;
            //TODO: dispatch_barrier_sync 和 dispatch_barrier_async
            /**
             * dispatch_barrier_sync: 提交一个栅栏函数在执行中,它会等待栅栏函数执行完(不管是否是在队列中的操作)(不管执行顺序只管让他之前的完成才执行后面的)
             * dispatch_barrier_async:提交一个栅栏函数在异步执行中,它会立马返回(只管在队列中的)(操作都在它之前在它前面完成 后面的在它后面完成 其余的操作不管)
             */
            dispatch_sync(sself.barrierQueue, ^{
                callbacksForURL = [sself.URLCallbacks[url] copy];
            });
            dispatch_async(dispatch_get_main_queue(), ^{
                WQVoiceDownProgressBlock callback = callbacksForURL[kProgressCallbackKey];
                if (callback) callback(downloadProgress);
            });
            
        } complete:^(id  _Nullable voiceMedia,NSURL *resourceURL, NSError * _Nullable error) {
            WQVoiceDownloader *sself = wself;
            if (!sself) return;
            
            
            __block NSDictionary *callbacksForURL;
            dispatch_barrier_sync(sself.barrierQueue, ^{
                callbacksForURL = [sself.URLCallbacks[url] copy];
                [sself.URLCallbacks removeObjectForKey:url];
                
            });
            WQVoiceDownCompleteBlock callback = callbacksForURL[kCompletedCallbackKey];
            if (sself.conversionOperation) {
                NSData *convertData = sself.conversionOperation(voiceMedia);
                [sself _cacheMedia:convertData resourceURL:resourceURL];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (callback) callback(convertData ,resourceURL, error);
                });
            }else  if (sself.convertStyle != WQConvertVoiceNone) {
                NSString *targetPath ;
                if (sself.shouldCache) {
                    targetPath = [sself.voiceCache defaultCachePathForURL:resourceURL];
                }
                [sself.conversionTool voiceConversion:sself.convertStyle from:voiceMedia targetPath:targetPath compeletion:^(NSError *error,  id convertData) {
                    if (callback) callback(convertData ,url, error);
                }];
            }else{
                [sself _cacheMedia:voiceMedia resourceURL:resourceURL];
                dispatch_async(dispatch_get_main_queue(), ^{
                    if (callback) callback(voiceMedia ,url, error);
                });
            }
            
        } cancelBlock:^{
            WQVoiceDownloader *sself = wself;
            if (!sself) return;
            dispatch_barrier_async(sself.barrierQueue, ^{
                [sself.URLCallbacks removeObjectForKey:url];
            });
        } ];
        [wself.downloadQueue addOperation:operation];
    }];
}

- (void)_cacheMedia:(id)voiceMedia resourceURL:(NSURL *)resourceURL{
    if (self.shouldCache && voiceMedia && resourceURL) {
        NSString *targetKey = [self.voiceCache cacheKeyForURL:resourceURL];
        
        if ([voiceMedia isKindOfClass:[NSData class]]) {
              [self.voiceCache storeVoice:voiceMedia forKey:targetKey];
        }else{
            [self.voiceCache moveVoice:voiceMedia forkey:targetKey];
        }
    }
}
//TODO: 相同的音频路径 就覆盖之前的回调block
- (void)addProgressCallback:(WQVoiceDownProgressBlock)progressBlock completedBlock:(WQVoiceDownCompleteBlock)completedBlock forURL:(NSURL *)url createCallback:(dispatch_block_t)createCallback {
    // The URL will be used as the key to the callbacks dictionary so it cannot be nil. If it is nil immediately call the completed block with no image or data.
    if (url == nil) {
        if (completedBlock != nil) {
            completedBlock( nil,nil, [NSError errorWithDomain:WQVoiceErrorDomain code:0 userInfo:@{NSLocalizedDescriptionKey:@"path is empty"}]);
        }
        return;
    }
    
    dispatch_barrier_sync(self.barrierQueue, ^{
        BOOL first = NO;
        if (!self.URLCallbacks[url]) {
//            self.URLCallbacks[url] = [NSMutableArray new];
            first = YES;
        }
        
        // Handle single download of simultaneous download request for the same URL
//        NSMutableArray *callbacksForURL = self.URLCallbacks[url];
        NSMutableDictionary *callbacks = [NSMutableDictionary new];
        if (progressBlock) callbacks[kProgressCallbackKey] = [progressBlock copy];
        if (completedBlock) callbacks[kCompletedCallbackKey] = [completedBlock copy];
//        [callbacksForURL addObject:callbacks];
        self.URLCallbacks[url] = callbacks;
        
        if (first) {
            createCallback();
        }
    });
}

-(void)cancelAllOperations{
    [self.downloadQueue cancelAllOperations];
//    [self.downloadOperations removeAllObjects];
}
#pragma mark Helper methods

- (WQVoiceDownloadOperation *)operationWithTask:(NSURLSessionTask *)task {
    WQVoiceDownloadOperation *returnOperation = nil;
    for (WQVoiceDownloadOperation *operation in self.downloadQueue.operations) {
        if (operation.dataTask.taskIdentifier == task.taskIdentifier) {
            returnOperation = operation;
            break;
        }
    }
    return returnOperation;
}

#pragma mark NSURLSessionDataDelegate

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
didReceiveResponse:(NSURLResponse *)response
 completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler {
    
    // Identify the operation that runs this task and pass it the delegate method
    WQVoiceDownloadOperation *dataOperation = [self operationWithTask:dataTask];
    
    [dataOperation URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    
    // Identify the operation that runs this task and pass it the delegate method
    WQVoiceDownloadOperation *dataOperation = [self operationWithTask:dataTask];
    
    [dataOperation URLSession:session dataTask:dataTask didReceiveData:data];
}

- (void)URLSession:(NSURLSession *)session
          dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse *cachedResponse))completionHandler {
    
    // Identify the operation that runs this task and pass it the delegate method
    WQVoiceDownloadOperation *dataOperation = [self operationWithTask:dataTask];
    
    [dataOperation URLSession:session dataTask:dataTask willCacheResponse:proposedResponse completionHandler:completionHandler];
}

#pragma mark NSURLSessionTaskDelegate

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    // Identify the operation that runs this task and pass it the delegate method
    WQVoiceDownloadOperation *dataOperation = [self operationWithTask:task];
    
    [dataOperation URLSession:session task:task didCompleteWithError:error];
}
// 只要访问的是HTTPS的路径就会调用
// 该方法的作用就是处理服务器返回的证书, 需要在该方法中告诉系统是否需要安装服务器返回的证书
// NSURLAuthenticationChallenge : 授权质问
//+ 受保护空间
//+ 服务器返回的证书类型
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential *credential))completionHandler {
    
    // Identify the operation that runs this task and pass it the delegate method
    WQVoiceDownloadOperation *dataOperation = [self operationWithTask:task];
    
    [dataOperation URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
}
-(void)dealloc{
    
    [self.session invalidateAndCancel];
    self.session = nil;
    
    [self cancelAllOperations];
  
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}
@end
