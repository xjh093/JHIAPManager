# JHIAPManager
In-App Purchase
- 关于内购

---

# Usage
Appdelegate.m
```
 - (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
 
    //内购监听-针对未完成支付
    [JHIAPManager iapManager].delegate = self;
    
    .....
 }
 
 - (void)jh_paymentSuccess:(SKPaymentTransaction *)transaction{
     //do something about buying
     //finish transaction
 }
 
```
