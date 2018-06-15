//
//  JHIAPManager.h
//  JHKit
//
//  Created by HaoCold on 2017/9/15.
//  Copyright © 2017年 HaoCold. All rights reserved.
//  In-App Purchase & 内购工具
//
//  MIT License
//
//  Copyright (c) 2017 xjh093
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

/**<
 
问题：
 「掉单」可能会出现在哪些环节：
 
 第1步，这个过程中 App 进程因为某种原因被 kill 了，其实支付行为还在系统后台进行着，苹果自己做的，很有可能扣款成功。但是这时候没法为用户充值虚拟货币。
 第2步，App 端与自己服务器端通信失败；自己服务器端与 AppStore 服务器之间的通信失败。
 
解决： 
 在了解了IAP支付机制之后，上面两种情况就有方法去解决了。
 
 针对第一种情况，可以在 App 一启动就设置监听，如果有未完成的支付，则会回调- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions;这个方法，在这个方法里调用接口充值。
 
 至于第二种情况，App 端需要做接口重试，设置一个重试的逻辑。
 
 作者：笑谈红尘乱离人
 链接：http://www.jianshu.com/p/d8bf952a023a
 來源：简书
 */

#import <Foundation/Foundation.h>
#import <StoreKit/StoreKit.h>

@protocol JHIAPManagerDelegate <NSObject>

/**< 
 - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
 
    //内购监听-针对未完成支付
    [JHIAPManager iapManager].delegate = self;
    
    .....
 
 }
 
 */
///在此方法内，调用后台的支付验证接口，给用户充值
- (void)jh_paymentSuccess:(SKPaymentTransaction *)transaction;

@end

@interface JHIAPManager : NSObject

///在AppDelegate内设置代理，处理未完成的支付
@property (weak,    nonatomic) id <JHIAPManagerDelegate> delegate;

+ (instancetype)iapManager;

///购买商品 applicationUsername:一般是后台定单号
- (void)jh_addPayment:(NSString *)productID
             username:(NSString *)applicationUsername
              success:(void (^)(SKPaymentTransaction *transaction))success
              failure:(void (^)(SKPaymentTransaction *transaction, NSError *error))failure;

///票据信息
- (NSString *)jh_receiptString;

///完成购买
- (void)jh_finishTransaction:(SKPaymentTransaction *)transaction;
@end
 
 
 @interface JHIAPManager (jailBreak)
/// iPhone is jailBreak?
- (BOOL)jh_isJailBreak;
@end
 
