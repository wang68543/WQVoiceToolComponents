//
//  ViewController.m
//  WQVoiceToolDemo
//
//  Created by WangQiang on 2017/5/25.
//  Copyright © 2017年 WQMapKit. All rights reserved.
//

#import "ViewController.h"
#import "WQVoicePlayManager.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
//    [[WQVoicePlayManager manager] play:@"http://down.qingkan520.com/5/5557.txt" playBegin:^(NSError *error, NSURL *url) {
//        NSLog(@"%@",url);
//    } playFinsh:^(NSError *error, NSURL *url, BOOL finshed) {
//        NSLog(@"===%@",url);
//    }];
    // Do any additional setup after loading the view, typically from a nib.
//    [[WQVoicePlayManager manager] play:@"http://down.qingkan520.com/5/5557.txt" playFinsh:^(NSError *error, NSURL *url, BOOL finshed) {
//        
//    }];
//    [[WQVoicePlayManager manager] play:@"http://down.qingkan520.com/5/5557.txt" downProgress:^(NSProgress *downloadProgress) {
//        NSLog(@"====%@",downloadProgress);
//    } downComplete:^(NSData *voiceData, NSString *cachePath, WQVoiceCacheType cacheType, NSURL *downURL, NSError *error) {
//        if(error){
//            
//        }else{
//            if(voiceData){
//               NSLog(@"cache==%@",cachePath); 
//            }else if(cachePath){
//             NSLog(@"cache==%@",cachePath);
//            }
//         
//        }
//        
//    }  playFinsh:^(NSError *error, NSURL *url, BOOL finshed) {
//        
//    }];
//    [[WQVoicePlayManager manager] play:@"http://free2.macx.cn:8281/tools/other7/TextSoap841.dmg" playFinsh:^(NSError *error, NSURL *url, BOOL finshed) {
//        
//    }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
