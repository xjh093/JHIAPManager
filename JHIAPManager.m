//
//  JHIAPManager.m
//  JHKit
//
//  Created by HaoCold on 2017/9/15.
//  Copyright © 2017年 HaoCold. All rights reserved.
//

#import "JHIAPManager.h"
#import <dlfcn.h>
#import <sys/stat.h>

#if DEBUG
#define JHIAPLog(...) NSLog(@"JHIAPLog: %@", [NSString stringWithFormat:__VA_ARGS__]);
#else
#define JHIAPLog(...)
#endif

NSString *const JHIAPManagerErrorDomain = @"com.haocold.jhiapmanager";
NSInteger const JHIAPManagerErrorCodeParameterIsNil = -1;
NSInteger const JHIAPManagerErrorCodeCanNotMakePayments = -2;
NSInteger const JHIAPManagerErrorCodeCanNotGetTheRequestProduct = -3;
NSInteger const JHIAPmanagerErrorCodeIsJailBreak = -4;

typedef void(^jhPaySuccessBlock)(SKPaymentTransaction *transaction);
typedef void(^jhPayFailureBlock)(SKPaymentTransaction *transaction, NSError *error);

@interface JHIAPManager()<SKPaymentTransactionObserver,SKProductsRequestDelegate>
@property (nonatomic,   copy) jhPaySuccessBlock paySuccessBlock;
@property (nonatomic,   copy) jhPayFailureBlock payFailureBlock;
@property (nonatomic,   copy) NSString *applicationUsername;
@end

@implementation JHIAPManager

+ (instancetype)iapManager{
    static JHIAPManager *iapManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        iapManager = [[JHIAPManager alloc] init];
    });
    return iapManager;
}

- (instancetype)init{
    if (self = [super init]) {
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)jh_addPayment:(NSString *)productID
             username:(NSString *)applicationUsername
              success:(void (^)(SKPaymentTransaction *transaction))success
              failure:(void (^)(SKPaymentTransaction *transaction, NSError *error))failure
{
    if (productID.length == 0) {
        NSError *error = [NSError errorWithDomain:JHIAPManagerErrorDomain code:JHIAPManagerErrorCodeParameterIsNil userInfo:@{NSLocalizedDescriptionKey:@"productID is nil"}];
        failure(nil,error);
        return;
    }
    
    if (applicationUsername.length == 0) {
        NSError *error = [NSError errorWithDomain:JHIAPManagerErrorDomain code:JHIAPManagerErrorCodeParameterIsNil userInfo:@{NSLocalizedDescriptionKey:@"applicationUsername is nil"}];
        failure(nil,error);
        return;
    }
    
    if (![SKPaymentQueue canMakePayments]) {
        NSError *error = [NSError errorWithDomain:JHIAPManagerErrorDomain code:JHIAPManagerErrorCodeCanNotMakePayments userInfo:@{NSLocalizedDescriptionKey:@"this device is not able or allowed to make payments"}];
        failure(nil,error);
        return;
    }
    
    if ([self jh_isJailBreak]) {
        NSError *error = [NSError errorWithDomain:JHIAPManagerErrorDomain code:JHIAPmanagerErrorCodeIsJailBreak userInfo:@{NSLocalizedDescriptionKey:@"this device is jailBreak, it's unsafe to make payments"}];
        failure(nil,error);
        return;
    }
    
    _applicationUsername = applicationUsername;
    _paySuccessBlock = success;
    _payFailureBlock = failure;
    
    //request
    NSSet *set = [NSSet setWithArray:@[productID]];
    SKProductsRequest *request = [[SKProductsRequest alloc]initWithProductIdentifiers:set];
    request.delegate = self;
    [request start];
}

- (NSString *)jh_receiptString{
    NSURL *receiptUrl = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = [NSData dataWithContentsOfURL:receiptUrl];
    NSString *receiptBase64String = [receiptData base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    return receiptBase64String;
}

- (void)jh_finishTransaction:(SKPaymentTransaction *)transaction{
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}

#pragma mark SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSArray *products = response.products;
    if (products.count == 0) {
        NSError *error = [NSError errorWithDomain:JHIAPManagerErrorDomain code:JHIAPManagerErrorCodeCanNotGetTheRequestProduct userInfo:@{NSLocalizedDescriptionKey:@"can not get the product from apple server"}];
        if (_payFailureBlock) {
            _payFailureBlock(nil,error);
        }
        return;
    }
    
    SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:products[0]];
    payment.applicationUsername = _applicationUsername;
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (void)requestDidFinish:(SKRequest *)request{
    
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    if (error && _payFailureBlock) {
        _payFailureBlock(nil,error);
    }
}

#pragma mark SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions {
    
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchasing://商品添加进列表
                break;
            case SKPaymentTransactionStatePurchased://交易完成
                [self jhPaymentSuccess:transaction];
                break;
            case SKPaymentTransactionStateFailed://交易失败
                [self jhPaymentFailure:transaction];
                break;
            case SKPaymentTransactionStateRestored://已经购买过该商品
                [self jhPaymentRestore:transaction];
                break;
            default:
                break;
        }
    }
}

#pragma mark --- transactionState handle

- (void)jhPaymentSuccess:(SKPaymentTransaction *)transaction {
    if (_paySuccessBlock) {
        _paySuccessBlock(transaction);
    }else if (_delegate && [_delegate respondsToSelector:@selector(jh_paymentSuccess:)]){
        [_delegate jh_paymentSuccess:transaction];
    }
}

- (void)jhPaymentFailure:(SKPaymentTransaction *)transaction {
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    if (_payFailureBlock) {
        _payFailureBlock(transaction,transaction.error);
    }
}

- (void)jhPaymentRestore:(SKPaymentTransaction *)transaction {
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
}

@end


@implementation JHIAPManager (jailBreak)

- (BOOL)jh_isJailBreak{
    if ([self isJailBreakForFilePath]) {
        return YES;
    }
    if ([self isJailBreakForOpenCydia]) {
        return YES;
    }
    if ([self isJailBreakForAllApplicationsName]) {
        return YES;
    }
    if ([self isJailBreakForStat]) {
        return YES;
    }
    if ([self isJailBreakForENV]) {
        return YES;
    }
    return NO;
}

#pragma mark - Pravite

- (BOOL)isJailBreakForFilePath {

    // 通过越狱后增加的越狱文件判断
    NSArray *pathArray = @[@"/Applications/Cydia.app",
                           @"/Library/MobileSubstrate/MobileSubstrate.dylib",
                           @"/bin/bash",
                           @"/usr/sbin/sshd",
                           @"/etc/apt"];
    
    for (int i = 0; i < pathArray.count; i++) {
        if ([[NSFileManager defaultManager] fileExistsAtPath:pathArray[i]]) {
            return YES;
        }
    }
    return NO;
}

- (BOOL)isJailBreakForOpenCydia {
    
    // 根据是否能打开cydia判断
    if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"cydia://"]]) {
        return YES;
    }
    return NO;
}

- (BOOL)isJailBreakForAllApplicationsName {
    
    // 根据是否能获取所有应用的名称判断
    if ([[NSFileManager defaultManager] fileExistsAtPath:@"User/Applications/"]) {
        // NSArray *appList = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:@"User/Applications/" error:nil];
        return YES;
    }
    return NO;
}

- (BOOL)isJailBreakForStat{
    
    // 根据使用stat方法来判断cydia是否存在来判断
    struct stat stat_info;
    
    // check inject
    int ret;
    Dl_info dylib_info;
    int (*func_stat)(const char*, struct stat*) = stat;
    char *dylib_name = "/usr/lib/system/libsystem_kernel.dylib";
    if ((ret = dladdr(func_stat, &dylib_info)) &&
        !strncmp(dylib_info.dli_fname, dylib_name, strlen(dylib_name))) {
        if (0 == stat("/Applications/Cydia.app", &stat_info)) {
            return YES;
        }
    }else{
        return YES;
    }
    return NO;
}

- (BOOL)isJailBreakForENV
{
    // 根据读取的环境变量是否有值判断
    // DYLD_INSERT_LIBRARIES环境变量在非越狱的设备上应该是空的，而越狱的设备基本上都会有Library/MobileSubstrate/MobileSubstrate.dylib

    char *env = getenv("DYLD_INSERT_LIBRARIES");
    if (env) {
        return YES;
    }
    return NO;
}

@end



