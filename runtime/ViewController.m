//
//  ViewController.m
//  runtime
//
//  Created by 赵申侃 on 2018/11/27.
//  Copyright © 2018 赵申侃. All rights reserved.
//

#import "ViewController.h"
#import <objc/message.h>
#import <objc/runtime.h>
#import "dog.h"


@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
//    objc_msgSend(self, @selector(eat));
//    dog *d = [[dog alloc] init];
//    [self hookFunc];
    Class cls = [self class];
    SEL selector = @selector(run:);
    Method method = class_getInstanceMethod(cls, selector);
    char *typeDescription = (char *)method_getTypeEncoding(method);
    char *forwardinvocationTyped = (char *)method_getTypeEncoding(class_getInstanceMethod(cls, @selector(forwardInvocation:)));
    char *oriTypeDes = (char *)method_getTypeEncoding(class_getInstanceMethod([self class], @selector(run:)));
    
    //新增一个方法指向原来的run的实现
    class_addMethod([self class], @selector(oriRun:), class_getMethodImplementation([self class], @selector(run:)), oriTypeDes);
    //新增一个oriForwardInvocation方法指向原来详细消息转发的实现,
    class_addMethod([self class], @selector(oriForwardInvocation:), class_getMethodImplementation([self class], @selector(forwardInvocation:)), forwardinvocationTyped);
    //让方法强行走消息转发
    class_replaceMethod(cls, selector, (IMP)_objc_msgForward, typeDescription);

    [self run:@"dog"];
//    objc_msgSend(self, @selector(eat:));
}

- (void)run:(NSString *)animal
{
    NSLog(@" vc----%@ run",animal);
}

- (void)myRun:(NSString *)animal
{
    NSLog(@" mydemohook---%@ run",animal);
    [self oriRun:animal];
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    //这里的run可以想办法藏起来
    if ([NSStringFromSelector(anInvocation.selector) isEqualToString:@"run:"]) {
        NSString *animal;
        [anInvocation getArgument:&animal atIndex:2];
        
        
        NSMethodSignature *signature = [self methodSignatureForSelector:@selector(myRun:)];
        NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
        [invocation setTarget:self];
        [invocation setSelector:@selector(myRun:)];
        [invocation setArgument:&animal atIndex:2];
        [invocation invokeWithTarget:self];
        return;
    }
    return [self oriForwardInvocation:anInvocation];
}

- (void)hookFunc
{
    Class cls = [self class];
    SEL selector = @selector(run);
    Method method = class_getInstanceMethod(cls, selector);
    IMP imp = method_getImplementation(method);
    
    //获得方法的参数类型
    char *typeDescription = (char *)method_getTypeEncoding(method);
    
    //新增一个eat方法，指向原来的run实现
    class_addMethod(cls, @selector(eat), imp, typeDescription);
    
    //dog eat函数指向了vcRun
    class_replaceMethod(cls, selector, class_getMethodImplementation([self class], @selector(bark)), typeDescription);
    
    [self run];
    //    [self eat];
}

- (void)run
{
    NSLog(@"run");
}

- (void)bark
{
    NSLog(@"bark");
    [self eat];
}

//- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
//{
//    NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
//    if (!signature) {
//        return [NSMethodSignature signatureWithObjCTypes:"v@:"];
//    }
//    return signature;
//}
//
//- (void)forwardInvocation:(NSInvocation *)anInvocation
//{
//    SEL sel = [anInvocation selector];
//    //转发给本类，给本类动态增加一个方法
////    if (![self respondsToSelector:sel]) {
////        class_addMethod([self class], sel, class_getMethodImplementation([self class], @selector(run)), "v@:");
////        return [anInvocation invokeWithTarget:self];
////    }
//
//    //把sel转给其他类的方法
//    dog *d = [[dog alloc] init];
//    if ([d respondsToSelector:sel]) {
//        return [anInvocation invokeWithTarget:d];
//    }
//    return [super forwardInvocation:anInvocation];
//}
//
//+ (IMP)instanceMethodForSelector:(SEL)aSelector
//{
//
//    return [super instanceMethodForSelector:aSelector];
//}
//
//- (void)doesNotRecognizeSelector:(SEL)aSelector
//{
//
//    return [super doesNotRecognizeSelector:aSelector];
//}


@end
