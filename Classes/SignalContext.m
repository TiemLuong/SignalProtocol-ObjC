#import "SignalCommonCryptoProvider.h"
#import "SignalContext_Internal.h"
#import "SignalStorage_Internal.h"

static void signal_lock(void *user_data);
static void signal_unlock(void *user_data);
static void signal_log(int level, const char *message, size_t len, void *user_data);

@interface SignalContext ()
@property (readonly, nonatomic) NSRecursiveLock *lock;
@end

@implementation SignalContext

- (void)dealloc {
    if (_context) {
        signal_context_destroy(_context);
    }
    _context = NULL;
}

- (instancetype)initWithStorage:(SignalStorage *)storage {
    NSParameterAssert(storage);
    if (self = [super init]) {
        int result = signal_context_create(&_context, (__bridge void *)(self));
        if (result != 0) {
            return nil;
        }
        
        // Setup crypto provider
        SignalCommonCryptoProvider *myCryptoProvider = [[SignalCommonCryptoProvider alloc] init];
        signal_crypto_provider cryptoProvider = [myCryptoProvider cryptoProvider];
        signal_context_set_crypto_provider(_context, &cryptoProvider);
        
        // Logs & Locking
        _lock = [[NSRecursiveLock alloc] init];
        signal_context_set_locking_functions(_context, signal_lock, signal_unlock);
        signal_context_set_log_function(_context, signal_log);

        // Storage
        _storage = storage;
        [_storage setupWithContext:_context];
    }
    return self;
}

@end

#pragma mark Locking

static void signal_lock(void *user_data) {
    SignalContext *context = (__bridge SignalContext *)(user_data);
    [context.lock lock];
}

static void signal_unlock(void *user_data) {
    SignalContext *context = (__bridge SignalContext *)(user_data);
    [context.lock unlock];
}

#pragma mark Logging

static void signal_log(int level, const char *message, size_t len, void *user_data) {
#if DEBUG
    NSLog(@"SignalProtocol (%d): %@", level, [NSString stringWithUTF8String:message]);
#endif
}
