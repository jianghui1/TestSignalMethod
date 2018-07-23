# RACSignal中的方法解读
### 这篇文章将`RACSignal`中的方法从头到尾分析一遍。

阅读前请下载[这个项目](https://github.com/jianghui1/TestSignalMethod.git),里面有对每个方法的测试。

***
    + (RACSignal *)createSignal:(RACDisposable * (^)(id<RACSubscriber> subscriber))didSubscribe {
    	return [RACDynamicSignal createSignal:didSubscribe];
    }
通常情况下，我们自己创建的信号都是通过这个方法， 里面其实是使用了一个具体类`RACDynamicSignal`创建一个信号。如果对信号及其子类不了解的话，可以看[这篇文章](http://blog.leichunfeng.com/blog/2015/12/25/reactivecocoa-v2-dot-5-yuan-ma-jie-xi-zhi-jia-gou-zong-lan/)。
***

    + (RACSignal *)error:(NSError *)error {
    	return [RACErrorSignal error:error];
    }
返回一个子类信号`RACErrorSignal`，专门处理错误的信号。
***
    
    + (RACSignal *)never {
    	return [[self createSignal:^ RACDisposable * (id<RACSubscriber> subscriber) {
    		return nil;
    	}] setNameWithFormat:@"+never"];
    }
创建了一个信号，但是不发送任何值。
***

    + (RACSignal *)startEagerlyWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block {
    	NSCParameterAssert(scheduler != nil);
    	NSCParameterAssert(block != NULL);
    
    	RACSignal *signal = [self startLazilyWithScheduler:scheduler block:block];
    	// Subscribe to force the lazy signal to call its block.
    	[[signal publish] connect];
    	return [signal setNameWithFormat:@"+startEagerlyWithScheduler: %@ block:", scheduler];
    }
    
    + (RACSignal *)startLazilyWithScheduler:(RACScheduler *)scheduler block:(void (^)(id<RACSubscriber> subscriber))block {
    	NSCParameterAssert(scheduler != nil);
    	NSCParameterAssert(block != NULL);
    
    	RACMulticastConnection *connection = [[RACSignal
    		createSignal:^ id (id<RACSubscriber> subscriber) {
    			block(subscriber);
    			return nil;
    		}]
    		multicast:[RACReplaySubject subject]];
    	
    	return [[[RACSignal
    		createSignal:^ id (id<RACSubscriber> subscriber) {
    			[connection.signal subscribe:subscriber];
    			[connection connect];
    			return nil;
    		}]
    		subscribeOn:scheduler]
    		setNameWithFormat:@"+startLazilyWithScheduler: %@ block:", scheduler];
    }
先看下`Lazily`方法，顾名思义，就是懒惰的意思，那`Eagerly`就是急切了。首先通过`multicast:`创建一个`RACMulticastConnection`对象，这里简单看下`RACReplaySubject`，针对`subject`会在以后进行详细的分析。
    
    - (instancetype)init {
    	return [self initWithCapacity:RACReplaySubjectUnlimitedCapacity];
    }
    
    - (RACDisposable *)subscribe:(id<RACSubscriber>)subscriber {
    	RACCompoundDisposable *compoundDisposable = [RACCompoundDisposable compoundDisposable];
    
    	RACDisposable *schedulingDisposable = [RACScheduler.subscriptionScheduler schedule:^{
    		@synchronized (self) {
    			for (id value in self.valuesReceived) {
    				if (compoundDisposable.disposed) return;
    
    				[subscriber sendNext:(value == RACTupleNil.tupleNil ? nil : value)];
    			}
    
    			if (compoundDisposable.disposed) return;
    
    			if (self.hasCompleted) {
    				[subscriber sendCompleted];
    			} else if (self.hasError) {
    				[subscriber sendError:self.error];
    			} else {
    				RACDisposable *subscriptionDisposable = [super subscribe:subscriber];
    				[compoundDisposable addDisposable:subscriptionDisposable];
    			}
    		}
    	}];
    
    	[compoundDisposable addDisposable:schedulingDisposable];
    
    	return compoundDisposable;
    }
    
    #pragma mark RACSubscriber
    
    - (void)sendNext:(id)value {
    	@synchronized (self) {
    		[self.valuesReceived addObject:value ?: RACTupleNil.tupleNil];
    		[super sendNext:value];
    		
    		if (self.capacity != RACReplaySubjectUnlimitedCapacity && self.valuesReceived.count > self.capacity) {
    			[self.valuesReceived removeObjectsInRange:NSMakeRange(0, self.valuesReceived.count - self.capacity)];
    		}
    	}
    }
    
    - (void)sendCompleted {
    	@synchronized (self) {
    		self.hasCompleted = YES;
    		[super sendCompleted];
    	}
    }
    
    - (void)sendError:(NSError *)e {
    	@synchronized (self) {
    		self.hasError = YES;
    		self.error = e;
    		[super sendError:e];
    	}
    }
可以看到内部通过`valuesReceived`保存之前发送的`value`，以便下次重新订阅时使用。然后调用父类`RACSubject`方法将新订阅信号通过数组保存下来，完成对多个信号的订阅。

再看下`multicast:`方法：
    
    - (RACMulticastConnection *)multicast:(RACSubject *)subject {
    	[subject setNameWithFormat:@"[%@] -multicast: %@", self.name, subject.name];
    	RACMulticastConnection *connection = [[RACMulticastConnection alloc] initWithSourceSignal:self subject:subject];
    	return connection;
    }
创建了一个`RACMulticastConnection`对象。代码如下：
    
        - (id)initWithSourceSignal:(RACSignal *)source subject:(RACSubject *)subject {
    	NSCParameterAssert(source != nil);
    	NSCParameterAssert(subject != nil);
    
    	self = [super init];
    	if (self == nil) return nil;
    
    	_sourceSignal = source;
    	_serialDisposable = [[RACSerialDisposable alloc] init];
    	_signal = subject;
    	
    	return self;
    }
    
    #pragma mark Connecting
    
    - (RACDisposable *)connect {
    	BOOL shouldConnect = OSAtomicCompareAndSwap32Barrier(0, 1, &_hasConnected);
    
    	if (shouldConnect) {
    		self.serialDisposable.disposable = [self.sourceSignal subscribe:_signal];
    	}
    
    	return self.serialDisposable;
    }
    
    - (RACSignal *)autoconnect {
    	__block volatile int32_t subscriberCount = 0;
    
    	return [[RACSignal
    		createSignal:^(id<RACSubscriber> subscriber) {
    			OSAtomicIncrement32Barrier(&subscriberCount);
    
    			RACDisposable *subscriptionDisposable = [self.signal subscribe:subscriber];
    			RACDisposable *connectionDisposable = [self connect];
    
    			return [RACDisposable disposableWithBlock:^{
    				[subscriptionDisposable dispose];
    
    				if (OSAtomicDecrement32Barrier(&subscriberCount) == 0) {
    					[connectionDisposable dispose];
    				}
    			}];
    		}]
    		setNameWithFormat:@"[%@] -autoconnect", self.signal.name];
    }
通过`BOOL shouldConnect = OSAtomicCompareAndSwap32Barrier(0, 1, &_hasConnected);`来达到只对源信号订阅一次。即便外部多次调用，最后对源信号也是一次订阅，然后通过`RACReplaySubject`将第一次订阅的值保存下来，用于其他调用的值返回。

接着继续看`Lazily`方法，创建一个信号，内部通过`[connection connect];`完成订阅。这个就是懒惰的原因，如果只是调用这个方法创建一个信号，不会有额外操作，只有外部订阅这个信号，才能够完成订阅过程。

接下来看看`Eagerly`的实现。首先通过`Lazily`方法拿到一个懒惰的信号，然后通过`publish`创建了一个`RACMulticastConnection`对象，紧接着调用了`connect`开始了信号的订阅。所以当外部直接调用此方法的时候，就已经开始了信号的订阅，也就是急切的。这也就是冷信号与热信号。
***
    - (RACSignal *)logNext {
    	return [[self doNext:^(id x) {
    		NSLog(@"%@ next: %@", self, x);
    	}] setNameWithFormat:@"%@", self.name];
    }
    - (RACSignal *)doNext:(void (^)(id x))block {
    	NSCParameterAssert(block != NULL);
    
    	return [[RACSignal createSignal:^(id<RACSubscriber> subscriber) {
    		return [self subscribeNext:^(id x) {
    			block(x);
    			[subscriber sendNext:x];
    		} error:^(NSError *error) {
    			[subscriber sendError:error];
    		} completed:^{
    			[subscriber sendCompleted];
    		}];
    	}] setNameWithFormat:@"[%@] -doNext:", self.name];
    }
`doNext:`当信号有值来的时候通过`block(x)`先执行一段逻辑，然后进行值的发送。此时的`block(x)`就是`NSLog(@"%@ next: %@", self, x);`，所以`logNext`就是在信号收到值之前打印一下当前的信号与当前的值，而`doNext:`就是在收到值之前做一些额外的操作。

`logError` `doError:` `logCompleted` `doCompleted`的功能也是类似的。

`logAll` 通过调用上面的函数分别打印出各个事件。
***

    - (id)asynchronousFirstOrDefault:(id)defaultValue success:(BOOL *)success error:(NSError **)error {
    	NSCAssert([NSThread isMainThread], @"%s should only be used from the main thread", __func__);
    
    	__block id result = defaultValue;
    	__block BOOL done = NO;
    
    	// Ensures that we don't pass values across thread boundaries by reference.
    	__block NSError *localError;
    	__block BOOL localSuccess = YES;
    
    	[[[[self
    		take:1]
    		timeout:RACSignalAsynchronousWaitTimeout onScheduler:[RACScheduler scheduler]]
    		deliverOn:RACScheduler.mainThreadScheduler]
    		subscribeNext:^(id x) {
    			result = x;
    			done = YES;
    		} error:^(NSError *e) {
    			if (!done) {
    				localSuccess = NO;
    				localError = e;
    				done = YES;
    			}
    		} completed:^{
    			done = YES;
    		}];
    	
    	do {
    		[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    	} while (!done);
    
    	if (success != NULL) *success = localSuccess;
    	if (error != NULL) *error = localError;
    
    	return result;
    }
首先看下这个函数的注释：
    
    /// Spins the main run loop for a short while, waiting for the receiver to send a `next`.
    ///
    /// **Because this method executes the run loop recursively, it should only be used
    /// on the main thread, and only from a unit test.**
这个方法只能运行于主线程，并且只能用来做单元测试。

方法内通过`take:1`只取一个值，通过`RACSignalAsynchronousWaitTimeout`设置一个超时时间，然后通过`[NSRunLoop.mainRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];`保证一直运行，这样在单元测试的时候就可以进行网络请求了。最终会返回运行结果。
***

    - (BOOL)asynchronouslyWaitUntilCompleted:(NSError **)error {
    	BOOL success = NO;
    	[[self ignoreValues] asynchronousFirstOrDefault:nil success:&success error:error];
    	return success;
    }
这个方法通过`ignoreValues`忽略所有的值，只关注信号是否完成，通过返回值`success`获取到最终结果。
