//
//  JHIAPManager.m
//  JHKit
//
//  Created by HaoCold on 2017/9/15.
//  Copyright © 2017年 HaoCold. All rights reserved.
//

#import "JHIAPManager.h"

#if DEBUG
#define JHIAPLog(...) NSLog(@"JHIAPLog: %@", [NSString stringWithFormat:__VA_ARGS__]);
#else
#define JHIAPLog(...)
#endif

NSString *const JHIAPManagerErrorDomain = @"com.haocold.jhiapmanager";
NSInteger const JHIAPManagerErrorCodeParameterIsNil = -1;
NSInteger const JHIAPManagerErrorCodeCanNotMakePayments = -2;
NSInteger const JHIAPManagerErrorCodeCanNotGetTheRequestProduct = -3;

typedef void(^jhPaySuccessBlock)(SKPaymentTransaction *transaction);
typedef void(^jhPayFailureBlock)(SKPaymentTransaction *transaction, NSError *error);

@interface JHIAPManager()<SKPaymentTransactionObserver,SKProductsRequestDelegate>
@property (nonatomic,   copy) jhPaySuccessBlock paySuccessBlock;
@property (nonatomic,   copy) jhPayFailureBlock payFailureBlock;
@property (nonatomic,   copy) NSString *applicationUsername;
@end

@implementation JHIAPManager

+ (void)load{
    [JHIAPManager iapManager];
}

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

