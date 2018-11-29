# objc_msgSend();
当一个对象收到一个消息（message）的时候，objc_msgSend 函数（messaging function） 会根据对象的 isa 指针 到 class dispatch table 里面去查找 method selector 。如果找不到呢？那就根据 isa 指针寻找到 superclass ，若是一直没有找到，那么就会沿着类继承层次来到了 NSObject 。一旦找到了 method selector,那么就调用 method selector 对应的方法实现并传入对应的参数。这就是 runtime 寻找方法实现的方式，消息动态绑定到方法实现。

```
例子:
- (void)viewDidLoad {
    [super viewDidLoad];
    SEL sel = @selector(run:);
    objc_msgSend(self,sel,@"dog");
}

 - (void)run:(NSString *)person{
    NSLog(@"%@ is running",person);
}
```

# NSInvocation
NSInvocation 是命令模式的一种实现。它把一个目标、一个选择器、一个方法签名、所有的参数都放到一个对象里面。当 NSInvocation 被调用的时候，Objective-C Runtime会执行正确的方法实现

```
    NSString *dog = @"dog";
    NSMethodSignature *signature = [self methodSignatureForSelector:@selector(run:)];
    NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
    [invocation setTarget:self];
    [invocation setSelector:@selector(run:)];
    //前两个参数分别是 target SEL
    [invocation setArgument:&dog atIndex:2];
    [invocation invoke];
```
# NSMethodSignature
方法签名 NSMethodSignature是一个方法的返回类型和参数类型，不包括方法名称。

```
NSMethodSignature *signature = [NSMethodSignature signatureWithObjCTypes:"@@:*"];
```
方法签名的 " @@:* " 字符串怎么理解呢？ 第一个字符 @ 表明返回值是一个 id。对于消息传递系统来说，所以的 Objective-C 对象都是 id 类型。 接下来的二个字符 @： 表明该方法接受一个 id 和一个 SEL 。其实每个 Objective-C 方法都把 id 和 SEL 作为头2个参数。最后一个字符 * 表示该方法的一个显式的参数是一个字符串（char*）。那如何获取这些类型编码呢，可以参考官方文档TypeEncodings，也可以直接使用类型编码@encode(type)获取表示该类型的字符串，而不必硬编码。
1. 比如：”v@:”意思就是这已是一个void类型的方法，没有参数传入。
2. 再比如 “i@:”就是说这是一个int类型的方法，没有参数传入。
3. 再再比如”i@:@”就是说这是一个int类型的方法，又一个参数传入。
```
NSLog(@"id Type encoding -->%s",@encode(id));
```
其他获取方法签名的方法

```
    SEL initSEL = @selector(init);// init 方法的选择器
    SEL allocSEL = @selector(alloc);// alloc 方法的选择器

    NSMethodSignature *initSignature, *allocSignature;
    // 从实例中获取实例方法签名
    initSignature = [@"Signature" methodSignatureForSelector:initSEL];
    // 从类中获取实例方法签名
    initSignature = [NSString instanceMethodSignatureForSelector:initSEL];
    // 从类中获取类方法签名
    allocSignature = [NSString methodSignatureForSelector:allocSEL];

```

# 消息转发
-  (BOOL)resolveInstanceMethod:(SEL)sel
-  (id)forwardingTargetForSelector:(SEL)aSelector
-  (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
-  (void)forwardInvocation:(NSInvocation *)anInvocation


1. 通过resolveInstanceMethod实现动态增加方法,
```
+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    if ([NSStringFromSelector(sel) isEqualToString:@"bark"]) {
        class_addMethod(self, sel, (IMP)eat, "v@:");
        return YES;
    }
    return [super resolveInstanceMethod:sel];
}

void eat(id self, SEL _cmd) {
    NSLog(@"125676");
}
```

```
+ (BOOL)resolveInstanceMethod:(SEL)sel
{
    if ([NSStringFromSelector(sel) isEqualToString:@"bark"]) {
        class_addMethod(self, sel, class_getMethodImplementation(self, @selector(eat)), "v@:");
        return YES;
    }
    return [super resolveInstanceMethod:sel];
}

- (void)eat
{
    NSLog(@"123");
}

```
class_addMethod 动态的给一个sel增加一个imp(函数实现方法)

2. (id)forwardingTargetForSelector:(SEL)aSelector

```
#import "dog.h"
#import "cat.h"
#import <objc/message.h>

@implementation dog

- (id)init
{
    if (self = [super init]) {
        [self eat];
    }
    return self;
}

- (id)forwardingTargetForSelector:(SEL)aSelector
{
    if ([NSStringFromSelector(@selector(eat)) isEqualToString:@"eat"]){
        cat *c = [[cat alloc] init];
        SEL sel = NSSelectorFromString(@"run");
        if ([c respondsToSelector:sel]) {
            return c;
        }
    }
    return [super forwardingTargetForSelector:aSelector];
}

@end
```

```
#import "cat.h"

@implementation cat

- (id)init
{
    if (self = [super init]) {
        
    }
    return self;
}

- (void)eat{
    NSLog(@"猫在吃");
}

@end

```

3. (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector,(void)forwardInvocation:(NSInvocation *)anInvocation
- 当methodSignatureForSelector返回nil时，会Crash
- 如果methodSignatureForSelector返回一个定义好的NSMethodSignature，但是没有实现forwardInvocation，也会闪退，如果实现了forwardInvocation，会先返回到resolveInstanceMethod然后再才会到forwardInvocation
- 当流转到forwardInvocation,通过以下方法:
```
[anInvocation invokeWithTarget:xxxtarget1];
[anInvocation invokeWithTarget:xxxtarget2];
```
还可以流转到多个对象,[anInvocation invokeWithTarget:xxxtarget2]是为了让不存在的方法有着陆点
- doesNotRecognizeSelector:(SEL)aSelector 执行到这里的时候，两种情况:
1. 当methodSignatureForSelector返回一种任意的方法签名的时候，也会进入doesNotRecognizeSelector，但是不会闪退
2. 当methodSignatureForSelector返回nil时，进入doesNotRecognizeSelector就会闪退
```
- (void)viewDidLoad {
    [super viewDidLoad];
    
    objc_msgSend(self, @selector(eat));
}

//- (void)eat
//{
//    NSLog(@"eat");
//}

- (void)run
{
    NSLog(@"runing");
}

- (NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
{
    NSMethodSignature *signature = [super methodSignatureForSelector:aSelector];
    if (!signature) {
        return [NSMethodSignature signatureWithObjCTypes:"v@:"];
    }
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)anInvocation
{
    SEL sel = [anInvocation selector];
    //转发给本类，给本类动态增加一个方法
//    if (![self respondsToSelector:sel]) {
//        class_addMethod([self class], sel, class_getMethodImplementation([self class], @selector(run)), "v@:");
//        return [anInvocation invokeWithTarget:self];
//    }
    
    //把sel转给其他类的方法
    dog *d = [[dog alloc] init];
    if ([d respondsToSelector:sel]) {
        return [anInvocation invokeWithTarget:d];
    }
    return [super forwardInvocation:anInvocation];
}

+ (IMP)instanceMethodForSelector:(SEL)aSelector
{
    
    return [super instanceMethodForSelector:aSelector];
}

- (void)doesNotRecognizeSelector:(SEL)aSelector
{
    
    return [super doesNotRecognizeSelector:aSelector];
}

```
详解:消息转发首先会进入(NSMethodSignature *)methodSignatureForSelector:(SEL)aSelector
1. 此时若返回的信号量为nil,doesNotRecognizeSelector
2. 若要进行消息转发,则手动给其增加一个相应的信号量,则进入(void)forwardInvocation:(NSInvocation *)anInvocation,此时有两种方式进行转发,一种是本类动态增加方法,一种是吧方法转给其他类


# Hook某个函数
```
- (void)viewDidLoad {
    [super viewDidLoad];
    
    Class cls = [self class];
    SEL selector = @selector(run);
    Method method = class_getInstanceMethod(cls, selector);
    IMP imp = method_getImplementation(method);
    
    //获得方法的参数类型
    char *typeDescription = (char *)method_getTypeEncoding(method);
    
    //新增一个eat方法，指向原来的run实现
    class_addMethod(cls, @selector(eat), imp, typeDescription);
    
    //dog run函数指向bark
    class_replaceMethod(cls, selector, class_getMethodImplementation([self class], @selector(bark)), typeDescription);
    
    [self run];
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

输出：
2018-11-28 16:30:46.833522+0800 runtime[43523:1310995] bark
2018-11-28 16:30:46.833672+0800 runtime[43523:1310995] run

```
这种方式不好传参数

2. 通过forwardInvocation进行传参

```
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
```

```
#import <UIKit/UIKit.h>

@interface ViewController : UIViewController

- (void)oriRun:(NSString *)animal;
- (void)oriForwardInvocation:(NSInvocation *)anInvocation;
- (void)eat;


@end


```





