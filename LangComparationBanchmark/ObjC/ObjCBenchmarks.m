// ObjCBenchmarks.m
#import "ObjCBenchmarks.h"
#import <Foundation/Foundation.h>
#include <mach/mach_time.h>

// ===== C-бріджі в Swift для CSV =====
extern void bench_open_session_c(const char *name);
extern void bench_log_samples_c(const char *key, const char *caseName, const char *language,
                                const double *samples, int32_t count);
extern void bench_close_session_c(void);

// ===== Таймер і утиліти вимірювань =====
static inline uint64_t now_nanos(void) {
    static mach_timebase_info_data_t info = {0,0};
    if (info.denom == 0) {
        mach_timebase_info(&info);
    }
    uint64_t t = mach_absolute_time();
    return t * info.numer / info.denom;
}

// Вимірювання: виконує warmup, потім samples запусків; результат у out[0..samples-1]
static void measure(const char *label,
                    int samples,
                    int warmup,
                    void (^block)(void),
                    double *out,
                    int *outCount) {
    (void)label;
    for (int i = 0; i < warmup; i++) {
        block();
    }
    for (int i = 0; i < samples; i++) {
        uint64_t t0 = now_nanos();
        block();
        uint64_t t1 = now_nanos();
        out[i] = (double)(t1 - t0);
    }
    *outCount = samples;
}

static void print_stats(const char *name, double *vals, int n) {
    double sum = 0, minv = vals[0], maxv = vals[0];
    for (int i = 0; i < n; i++) {
        sum += vals[i];
        if (vals[i] < minv) minv = vals[i];
        if (vals[i] > maxv) maxv = vals[i];
    }
    double avg = sum / n;

    // Обчислюємо стандартне відхилення
    double variance = 0;
    for (int i = 0; i < n; i++) {
        double diff = vals[i] - avg;
        variance += diff * diff;
    }
    variance /= n;
    double std = sqrt(variance);

    // Сортування для медіани
    for (int i = 0; i < n - 1; i++)
        for (int j = i + 1; j < n; j++)
            if (vals[j] < vals[i]) {
                double t = vals[i];
                vals[i] = vals[j];
                vals[j] = t;
            }
    double median = vals[n / 2];

    printf("\n==> %s\n", name);
    printf("avg: %.0f ns, std: %.0f ns, median: %.0f ns, min: %.0f, max: %.0f\n",
           avg, std, median, minv, maxv);
}

// ===== Допоміжний логер для виклику з кожного кейсу =====
static inline void log_case(const char *key, const char *caseName, double *vals, int count) {
    bench_log_samples_c(key, caseName, "ObjC", vals, (int32_t)count);
}

// ===== Основний раннер =====
void runObjCBenchmarks(void) {
    printf("Objective-C Benchmarks: samples per case = 10 (ns per run)\n\n");
    const int samples = 10, warmup = 3;
    double vals[64]; int cnt = 0;

    // ---------- NSMutableArray: add/insert ----------
    @autoreleasepool {
        const int count = 100000;

        measure("NSMutableArray addObject with capacity", samples, warmup, ^{
            NSMutableArray<NSNumber*> *a = [NSMutableArray arrayWithCapacity:count];
            for (int i = 0; i < count; i++) { [a addObject:@(i)]; }
        }, vals, &cnt);
        print_stats("NSMutableArray addObject with capacity", vals, cnt);
        log_case("array_append_reserve", "NSMutableArray addObject with capacity", vals, cnt);

        measure("NSMutableArray addObject no capacity", samples, warmup, ^{
            NSMutableArray<NSNumber*> *a = [NSMutableArray array];
            for (int i = 0; i < count; i++) { [a addObject:@(i)]; }
        }, vals, &cnt);
        print_stats("NSMutableArray addObject no capacity", vals, cnt);
        log_case("array_append_no_reserve", "NSMutableArray addObject no capacity", vals, cnt);

        const int insertCount = 10000;
        measure("NSMutableArray insert at 0", samples, warmup, ^{
            NSMutableArray<NSNumber*> *a = [NSMutableArray array];
            for (int i = 0; i < insertCount; i++) { [a insertObject:@(i) atIndex:0]; }
        }, vals, &cnt);
        print_stats("NSMutableArray insert at 0", vals, cnt);
        log_case("array_insert_at_zero", "NSMutableArray insert at 0", vals, cnt);
    }

    // ---------- NSDictionary lookup (hit) ----------
    @autoreleasepool {
        const int size = 100000;
        const int lookups = 2000000;
        NSMutableDictionary<NSNumber*, NSNumber*> *d = [NSMutableDictionary dictionaryWithCapacity:size];
        for (int i = 0; i < size; i++) { d[@(i)] = @(i); }

        measure("NSDictionary lookup hit", samples, warmup, ^{
            int sum = 0;
            for (int i = 0; i < lookups; i++) { sum += [d[@(i % size)] intValue]; }
            (void)sum;
        }, vals, &cnt);
        print_stats("NSDictionary lookup hit", vals, cnt);
        log_case("dict_lookup_hit", "NSDictionary lookup hit", vals, cnt);
    }

    // ---------- NSSet contains ----------
    @autoreleasepool {
        const int size = 100000;
        const int lookups = 2000000;
        NSMutableSet<NSNumber*> *s = [NSMutableSet setWithCapacity:size];
        for (int i = 0; i < size; i++) { [s addObject:@(i)]; }

        measure("NSSet contains", samples, warmup, ^{
            int hits = 0;
            for (int i = 0; i < lookups; i++) { if ([s containsObject:@(i % size)]) hits++; }
            (void)hits;
        }, vals, &cnt);
        print_stats("NSSet contains", vals, cnt);
        log_case("set_contains", "NSSet contains", vals, cnt);
    }
    
    // ---------- Blocks: NON-CAPTURING (окремий кейс) ----------
    @autoreleasepool {
        const int calls = 5000000;
        int (^noncap)(void) = ^{ return 1; };

        measure("block non-capturing", samples, warmup, ^{
            int acc = 0; for (int i = 0; i < calls; i++) { acc += noncap(); } (void)acc;
        }, vals, &cnt);
        print_stats("block non-capturing", vals, cnt);
        log_case("closure-non-captured", "block non-capturing", vals, cnt);
    }

    // ---------- Blocks: CAPTURING (окремий кейс) ----------
    @autoreleasepool {
        const int calls = 5000000;
        __block int x = 1;               // гарантуємо захоплення змінної
        int (^cap)(void) = ^{ return x; };

        measure("block capturing", samples, warmup, ^{
            int acc = 0; for (int i = 0; i < calls; i++) { acc += cap(); } (void)acc;
        }, vals, &cnt);
        print_stats("block capturing", vals, cnt);
        log_case("closure-captured", "block capturing", vals, cnt);
    }
    
    // ---------- NSString '+' (stringByAppendingString:) ----------
    @autoreleasepool {
        const int parts = 20000;

        measure("NSString + (stringByAppendingString:)", samples, warmup, ^{
            NSString *s = @"";
            for (int i = 0; i < parts; i++) {
                s = [s stringByAppendingString:[[NSNumber numberWithInt:i] stringValue]];
            }
            (void)s;
        }, vals, &cnt);
        print_stats("NSString + (stringByAppendingString:)", vals, cnt);
        log_case("string_concatenation", "NSString + (stringByAppendingString:)", vals, cnt);
    }

    // ---------- NSMutableString with capacity + append ----------
    @autoreleasepool {
        const int parts = 20000;

        measure("NSMutableString (capacity + appendString:)", samples, warmup, ^{
            NSMutableString *ms = [[NSMutableString alloc] initWithCapacity:parts * 2];
            for (int i = 0; i < parts; i++) {
                [ms appendString:[[NSNumber numberWithInt:i] stringValue]];
            }
            (void)ms;
        }, vals, &cnt);
        print_stats("NSMutableString (capacity + appendString:)", vals, cnt);
        log_case("string_reserve_append", "NSMutableString (capacity + appendString:)", vals, cnt);
    }

    // ---------- Autorelease pool + NSNumber ----------
    @autoreleasepool {
        const int allocs = 500000;
        measure("@autoreleasepool + NSNumber", samples, warmup, ^{
            @autoreleasepool {
                long sum = 0;
                for (int i = 0; i < allocs; i++) { NSNumber *n = @(i); sum += n.longValue; }
                (void)sum;
            }
        }, vals, &cnt);
        print_stats("@autoreleasepool + NSNumber", vals, cnt);
        log_case("autoreleasepool_overhead", "@autoreleasepool + NSNumber", vals, cnt);
    }

    // Закрити сесію (можна ініціювати пост-обробку на Swift-боці)
    bench_close_session_c();
}
