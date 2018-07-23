//
//  TestSignalMethodTests.m
//  TestSignalMethodTests
//
//  Created by ys on 2018/7/23.
//  Copyright © 2018年 ys. All rights reserved.
//

#import <XCTest/XCTest.h>

#import <ReactiveCocoa.h>

@interface TestSignalMethodTests : XCTestCase

@end

@implementation TestSignalMethodTests

- (RACSignal *)testCreateSignal
{
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        
        for (int i = 0; i < 2; i++) {
            [subscriber sendNext:@(i)];
        }
        
        return nil;
        
    }];
}

- (void)testError
{
    [[RACSignal error:[NSError errorWithDomain:NSCocoaErrorDomain code:1001 userInfo:nil]]
     subscribeNext:^(id x) {
         NSLog(@"值 -- %@", x);
     } error:^(NSError *error) {
         NSLog(@"失败了-- %@", error);
     } completed:^{
         NSLog(@"成功了");
     }];
    
    // 打印结果如下：
    // 2018-07-23 12:02:29.674875+0800 TestSignalMethod[18087:1409302] 失败了-- Error Domain=NSCocoaErrorDomain Code=1001 "(null)"
}

- (void)testNever
{
    [[RACSignal never]
     subscribeNext:^(id x) {
         NSLog(@"值 -- %@", x);
     } error:^(NSError *error) {
         NSLog(@"失败了-- %@", error);
     } completed:^{
         NSLog(@"成功了");
     }];
    
    // 无任何打印结果
}

- (void)testEagerly
{
    [RACSignal startEagerlyWithScheduler:[RACScheduler mainThreadScheduler] block:^(id<RACSubscriber> subscriber) {
        NSLog(@"subscriber -- %@", subscriber);
    }];
    
    // 打印结果如下：
    // 2018-07-23 12:06:42.856776+0800 TestSignalMethod[18294:1423111] subscriber -- <RACPassthroughSubscriber: 0x604000224420>
}

- (void)testLazily1
{
    [RACSignal startLazilyWithScheduler:[RACScheduler mainThreadScheduler] block:^(id<RACSubscriber> subscriber) {
        NSLog(@"subscriber -- %@", subscriber);
    }];
    
    // 打印结果如下：
    // 无任何打印结果
    
    [[RACSignal startLazilyWithScheduler:[RACScheduler mainThreadScheduler] block:^(id<RACSubscriber> subscriber) {
        NSLog(@"subscriber -- %@", subscriber);
    }]
     subscribeNext:^(id x) {
         NSLog(@"值 -- %@", x);
     } error:^(NSError *error) {
         NSLog(@"失败了-- %@", error);
     } completed:^{
         NSLog(@"成功了");
     }];
}

- (void)testLazily2
{
    [[RACSignal startLazilyWithScheduler:[RACScheduler mainThreadScheduler] block:^(id<RACSubscriber> subscriber) {
        NSLog(@"subscriber -- %@", subscriber);
    }]
     subscribeNext:^(id x) {
         NSLog(@"值 -- %@", x);
     } error:^(NSError *error) {
         NSLog(@"失败了-- %@", error);
     } completed:^{
         NSLog(@"成功了");
     }];
    
    // 打印结果如下：
    // 2018-07-23 12:09:58.107429+0800 TestSignalMethod[18472:1433945] subscriber -- <RACPassthroughSubscriber: 0x604000224ea0>
}

- (void)testLazily3
{
    [[RACSignal startLazilyWithScheduler:[RACScheduler mainThreadScheduler] block:^(id<RACSubscriber> subscriber) {
        NSLog(@"subscriber -- %@", subscriber);
        [subscriber sendNext:@(1)];
    }]
     subscribeNext:^(id x) {
         NSLog(@"值 -- %@", x);
     } error:^(NSError *error) {
         NSLog(@"失败了-- %@", error);
     } completed:^{
         NSLog(@"成功了");
     }];
    
    // 打印结果如下：
    // 2018-07-23 12:10:53.630908+0800 TestSignalMethod[18520:1436837] subscriber -- <RACPassthroughSubscriber: 0x6040004253e0>
    // 2018-07-23 12:10:53.631725+0800 TestSignalMethod[18520:1436837] 值 -- 1
}

- (void)testLogNext
{
    [[[self testCreateSignal] logNext]
     subscribeNext:^(id x) {
         NSLog(@"值 -- %@", x);
     }];
    
    // 打印结果如下：
    /*
     2018-07-23 12:13:34.496397+0800 TestSignalMethod[18635:1444929] <RACDynamicSignal: 0x6000004253a0> name:  next: 0
     2018-07-23 12:13:34.496614+0800 TestSignalMethod[18635:1444929] 值 -- 0
     2018-07-23 12:13:34.496772+0800 TestSignalMethod[18635:1444929] <RACDynamicSignal: 0x6000004253a0> name:  next: 1
     2018-07-23 12:13:34.496888+0800 TestSignalMethod[18635:1444929] 值 -- 1
     */
}

- (void)testDoNext
{
    [[[self testCreateSignal] doNext:^(id x) {
        NSLog(@"fuck -- %@", x);
    }]
     subscribeNext:^(id x) {
         NSLog(@"值 -- %@", x);
     }];
    
    // 打印结果如下：
    /*
     2018-07-23 12:15:06.442736+0800 TestSignalMethod[18710:1449777] fuck -- 0
     2018-07-23 12:15:06.442965+0800 TestSignalMethod[18710:1449777] 值 -- 0
     2018-07-23 12:15:06.443124+0800 TestSignalMethod[18710:1449777] fuck -- 1
     2018-07-23 12:15:06.443248+0800 TestSignalMethod[18710:1449777] 值 -- 1
     */
}

- (void)testLogCompleted
{
    RACSignal *signal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendCompleted];
        return nil;
    }];
    
    [[signal logCompleted]
     subscribeCompleted:^{
         NSLog(@"完成了");
     }];
    
    // 打印结果如下：
    /*
     2018-07-23 12:17:03.464032+0800 TestSignalMethod[18793:1455863] <RACDynamicSignal: 0x604000224f60> name:  completed
     2018-07-23 12:17:03.464308+0800 TestSignalMethod[18793:1455863] 完成了
     */
}

- (void)testLogError
{
    RACSignal *signal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendError:nil];
        return nil;
    }];
    
    [[signal logError]
     subscribeError:^(NSError *error) {
         NSLog(@"错误了");
     }];
    
    // 打印结果如下：
    /*
     2018-07-23 12:18:07.099434+0800 TestSignalMethod[18851:1459230] <RACDynamicSignal: 0x600000231ee0> name:  error: (null)
     2018-07-23 12:18:07.099837+0800 TestSignalMethod[18851:1459230] 错误了
     */
}

- (void)testLogAll
{
    RACSignal *signal = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@(1)];
        [subscriber sendCompleted];
        return nil;
    }];
    
    [[signal logAll]
     subscribeNext:^(id x) {
         NSLog(@"值 -- %@", x);
     } error:^(NSError *error) {
         NSLog(@"失败了-- %@", error);
     } completed:^{
         NSLog(@"成功了");
     }];
    
    // 打印结果如下：
    /*
     2018-07-23 12:19:39.426175+0800 TestSignalMethod[18926:1464049] <RACDynamicSignal: 0x604000232060> name:  next: 1
     2018-07-23 12:19:39.426638+0800 TestSignalMethod[18926:1464049] 值 -- 1
     2018-07-23 12:19:39.427749+0800 TestSignalMethod[18926:1464049] <RACDynamicSignal: 0x6040002320a0> name:  completed
     2018-07-23 12:19:39.428076+0800 TestSignalMethod[18926:1464049] 成功了
     */
    
    RACSignal *signal1 = [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        [subscriber sendNext:@(1)];
        [subscriber sendError:nil];
        return nil;
    }];
    
    [[signal1 logAll]
     subscribeNext:^(id x) {
         NSLog(@"值 -- %@", x);
     } error:^(NSError *error) {
         NSLog(@"失败了-- %@", error);
     } completed:^{
         NSLog(@"成功了");
     }];
    
    // 打印结果如下：
    /*
     2018-07-23 12:20:28.750845+0800 TestSignalMethod[18970:1466819] <RACDynamicSignal: 0x6040000317e0> name:  next: 1
     2018-07-23 12:20:28.750991+0800 TestSignalMethod[18970:1466819] 值 -- 1
     2018-07-23 12:20:28.751123+0800 TestSignalMethod[18970:1466819] <RACDynamicSignal: 0x604000030de0> name:  error: (null)
     2018-07-23 12:20:28.751261+0800 TestSignalMethod[18970:1466819] 失败了-- (null)
     */
}

- (RACSignal *)requsetSignal
{
    return [RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
        NSURLSession *session = [NSURLSession sharedSession];
        NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://www.baidu.com"]];
        NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:request
                                                    completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
                                                        if (!error) {
                                                            [subscriber sendNext:data];
                                                            [subscriber sendCompleted];
                                                        }
                                                        else {
                                                            [subscriber sendError:error];
                                                        }
                                                    }];
        [dataTask resume];
        
        return [RACDisposable disposableWithBlock:^{
            [dataTask cancel];
        }];
    }];
}

- (void)testRequest
{
    [[self requsetSignal]
     subscribeNext:^(id x) {
         NSLog(@"值 -%@", x);
     }
     error:^(NSError *error) {
        NSLog(@"错误了");
    } completed:^{
        NSLog(@"完成了");
    }];
    
    // 无任何打印日志
}

- (void)testAsynchronousFirstOrDefault
{
    BOOL success;
    NSError *error;
    id result = [[self requsetSignal]
      asynchronousFirstOrDefault:nil success:&success error:&error];
    NSLog(@"结果 -- %@", result);
    
    // 打印结果如下：
    /*
     2018-07-23 13:42:26.639317+0800 TestSignalMethod[20982:1586070] 结果 -- <3c21444f 43545950 45206874 6d6c3e3c 68746d6c 3e3c6865 61643e3c 6d657461 20687474 702d6571 7569763d 22636f6e 74656e74 2d747970 65222063 6f6e7465 6e743d22 74657874 2f68746d 6c3b6368 61727365 743d7574 662d3822 3e3c6d65 74612068 7474702d 65717569 763d2258 2d55412d 436f6d70 61746962 6c652220 636f6e74 656e743d 2249453d 45646765 223e3c6d 65746120 636f6e74 656e743d 226e6576 65722220 6e616d65 3d227265 66657272 6572223e 3c746974 6c653ee7 99bee5ba a6e4b880 e4b88bef bc8ce4bd a0e5b0b1 e79fa5e9 81933c2f 7469746c 653e3c73 74796c65 3e68746d 6c2c626f 64797b68 65696768 743a3130 30257d68 746d6c7b 6f766572 666c6f77 2d793a61 75746f7d 626f6479 7b666f6e 743a3132 70782061 7269616c 3b626163 6b67726f 756e643a 23666666 7d626f64 792c702c 666f726d 2c756c2c 6c697b6d 61726769 6e3a303b 70616464 696e673a 303b6c69 73742d73 74796c65 3a6e6f6e 657d626f 64792c66 6f726d7b 706f7369 74696f6e 3a72656c 61746976 657d7464 7b746578 742d616c 69676e3a 6c656674 7d696d67 7b626f72 6465723a 307d617b 636f6c6f 723a2330 30637d61 3a616374 6976657b 636f
     */
}

- (void)testAsynchronouslyWaitUntilCompleted
{
    NSError *error;
    BOOL success = [[self requsetSignal] asynchronouslyWaitUntilCompleted:&error];
    NSLog(@"结果 -- %d", success);
    
    // 打印结果如下：
    /*
     2018-07-23 13:42:50.327048+0800 TestSignalMethod[21007:1587450] 结果 -- 1
     */
}

@end
