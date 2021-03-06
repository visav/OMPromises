//
// OMPromiseTests.h
// OMPromisesTests
//
// Copyright (C) 2013 Oliver Mader
// 
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import <XCTest/XCTest.h>

#import "OMPromises.h"

@interface OMPromisesTests : XCTestCase

@property id result;
@property id result2;
@property NSError *error;

@end

@implementation OMPromisesTests

- (void)setUp {
    self.result = @.1337;
    self.result2 = @.31337;
    self.error = [NSError errorWithDomain:@"idontgiveadamn" code:1337 userInfo:nil];
}

#pragma mark - Return

- (void)testFulfilledPromise {
    OMPromise *promise = [OMPromise promiseWithResult:self.result];
    
    XCTAssertEqual(promise.state, OMPromiseStateFulfilled, @"Promise should be fulfilled");
    XCTAssertEqual(promise.result, self.result, @"Promise should have the supplied result");
    XCTAssertEqualWithAccuracy(promise.progress, 1.f, FLT_EPSILON, @"Progress should be 1");
}

- (void)testFailedPromise {
    OMPromise *promise = [OMPromise promiseWithError:self.error];
    
    XCTAssertEqual(promise.state, OMPromiseStateFailed, @"Promise should be failed");
    XCTAssertEqual(promise.error, self.error, @"Promise should have the supplied error");
    XCTAssertEqualWithAccuracy(promise.progress, 0.f, FLT_EPSILON, @"Progress should be 0");
}

#pragma mark - Callbacks

- (void)testBindOnAlreadyFulfilledPromise {
    OMPromise *promise = [OMPromise promiseWithResult:self.result];
    
    __block int called = 0;
    [[[promise fulfilled:^(id result) {
        XCTAssertEqual(result, self.result, @"The supplied result should be identical");
        called += 1;
    }] failed:^(NSError *error) {
        XCTFail(@"Fail should not have been called");
    }] progressed:^(float progress) {
        XCTFail(@"Progress should not have been called");
    }];
    
    XCTAssertEqual(called, 1, @"fulfilled-block should have been called once");
}

- (void)testBindsOnNotAlreadyFulfilledPromise {
    OMDeferred *deferred = [OMDeferred deferred];

    __block int called = 0, progressCalled = 0;
    [[[deferred.promise fulfilled:^(id result) {
        XCTAssertEqual(result, self.result, @"The supplied result should be identical");
        XCTAssertTrue(progressCalled, @"progress-block should have been called before fulfilled-block");
        called += 1;
    }] failed:^(NSError *error) {
        XCTFail(@"Fail should not have been called");
    }] progressed:^(float progress) {
        XCTAssertFalse(called, @"progressed-block should be called before fulfilled-block");
        XCTAssertEqualWithAccuracy(progress, 1.f, FLT_EPSILON, @"Progress should be 1");
        progressCalled += 1;
    }];

    XCTAssertEqual(called, 0, @"fulfilled-block should not have been called");
    [deferred fulfil:self.result];
    XCTAssertEqual(called, 1, @"fulfilled-block should have been called once");
    XCTAssertEqual(progressCalled, 1, @"progressed-block should have been called once");
}

- (void)testBindsOnAlreadyFailedPromise {
    OMPromise *promise = [OMPromise promiseWithError:self.error];

    __block int called = 0;
    [[[promise fulfilled:^(id result) {
        XCTFail(@"fulfilled-block should not have been called");
    }] failed:^(NSError *error) {
        XCTAssertEqual(error, self.error, @"The supplied error should be identical");
        called += 1;
    }] progressed:^(float progress) {
        XCTFail(@"progressed-block should not have been called");
    }];
    
    XCTAssertEqual(called, 1, @"failed-block should have been called once");
}

- (void)testBindsOnNotAlreadyFailedPromise {
    OMDeferred *deferred = [OMDeferred deferred];

    __block int called = 0;
    [[[deferred.promise fulfilled:^(id result) {
        XCTFail(@"fulfilled-block should not have been called");
    }] failed:^(NSError *error) {
        XCTAssertEqual(error, self.error, @"The supplied error should be identical");
        called += 1;
    }] progressed:^(float progress) {
        XCTFail(@"progressed-block should not have been called");
    }];
    
    XCTAssertEqual(called, 0, @"failed-block should not have been called yet");
    [deferred fail:self.error];
    XCTAssertEqual(called, 1, @"failed-block should have been called");
}

- (void)testIncreasingProgress {
    OMDeferred *deferred = [OMDeferred deferred];

    __block int called = 0;
    [deferred.promise progressed:^(float progress) {
        float values[] = {.1f, .5f, 1.f};
        XCTAssertEqualWithAccuracy(values[called], progress, FLT_EPSILON, @"Unexpected progress");
        called += 1;
    }];

    XCTAssertEqual(called, 0, @"progressed-block should not have been called until now");
    [deferred progress:.1f];
    XCTAssertEqual(called, 1, @"progressed-block should be called once");
    [deferred progress:.1f];
    XCTAssertEqual(called, 1, @"progressed-block should be called once");
    [deferred progress:.5f];
    XCTAssertEqual(called, 2, @"progressed-block should be called twice");
    [deferred fulfil:self.result];
    XCTAssertEqual(called, 3, @"progressed-block should be called three times");
}

- (void)testMultipleBindsOnNotAlreadyFulfilledPromise {
    OMDeferred *deferred = [OMDeferred deferred];

    __block int called1 = 0, called2 = 0;
    [[deferred.promise fulfilled:^(id result) {
        XCTAssertEqual(result, self.result, @"The supplied result should be identical");
        called1 += 1;
    }] fulfilled:^(id result) {
        XCTAssertEqual(result, self.result, @"The supplied result should be identical");
        called2 += 1;
    }];

    XCTAssertEqual(called1, 0, @"first fulfilled-block should not have been called yet");
    XCTAssertEqual(called2, 0, @"second fulfilled-block should not have been called yet");
    [deferred fulfil:self.result];
    XCTAssertEqual(called1, 1, @"first fulfilled-block should have been called once");
    XCTAssertEqual(called2, 1, @"second fulfilled-block should have been called once");
}

- (void)testMultipleBindsOnNotAlreadyFailedPromise {
    OMDeferred *deferred = [OMDeferred deferred];

    __block int called1 = 0, called2 = 0;
    [[deferred.promise failed:^(NSError *error) {
        XCTAssertEqual(error, self.error, @"The supplied error should be identical");
        called1 += 1;
    }] failed:^(NSError *error) {
        XCTAssertEqual(error, self.error, @"The supplied error should be identical");
        called2 += 1;
    }];

    XCTAssertEqual(called1, 0, @"first failed-block should not have been called yet");
    XCTAssertEqual(called2, 0, @"second failed-block should not have been called yet");
    [deferred fail:self.error];
    XCTAssertEqual(called1, 1, @"first failed-block should have been called once");
    XCTAssertEqual(called2, 1, @"second failed-block should have been called once");
}

#pragma mark - Bind

- (void)testThenReturnPromise {
    OMDeferred *deferred = [OMDeferred deferred];

    __block int called = 0, calledProgress = 0, calledFulfil = 0, calledFail = 0;
    OMDeferred *nextDeferred = [OMDeferred deferred];
    OMPromise *nextPromise = [[[deferred.promise then:^(id result) {
        XCTAssertEqual(result, self.result, @"Supplied result should be identical to the one passed to fulfil:");
        called += 1;
        return nextDeferred.promise;
    }] progressed:^(float progress) {
        float progressValues[] = {.5f, 1.f};
        XCTAssertEqualWithAccuracy(progress, progressValues[calledProgress], FLT_EPSILON, @"incorrect progress value");
        calledProgress += 1;
    }] fulfilled:^(id result) {
        XCTAssertEqual(result, self.result2, @"Supplied result should be identical to the one passed to fulfil:");
        calledFulfil += 1;
    }];
    
    [[[nextPromise then:^(id result) {
        return [OMPromise promiseWithError:self.error];
    }] then:^(id result) {
        XCTFail(@"On error then should short circuit");
        return result;
    }] failed:^(NSError *error) {
        XCTAssertEqual(error, self.error, @"Supplied error should be identical to previous error in chain");
        calledFail += 1;
    }];

    [deferred fulfil:self.result];
    XCTAssertEqual(nextPromise.state, OMPromiseStateUnfulfilled, @"Second promise should not be fulfilled yet");
    XCTAssertEqual(called, 1, @"then-block should have been called exactly once");
    XCTAssertEqual(calledProgress, 0, @"progressed-block should not have been called yet");

    [nextDeferred progress:.5f];
    [nextDeferred fulfil:self.result2];
    XCTAssertEqual(nextPromise.state, OMPromiseStateFulfilled, @"Second promise should be fulfilled");
    XCTAssertEqual(calledProgress, 2, @"progressed-block should have been called exactly twice");
    XCTAssertEqual(calledFulfil, 1, @"fulfilled-block should have been called exactly once");
    XCTAssertEqual(calledFail, 1, @"failed-block should have been called exactly once");
}

- (void)testThenReturnValue {
    OMDeferred *deferred = [OMDeferred deferred];

    __block int called = 0, calledFulfil = 0;
    OMPromise *nextPromise = [[[deferred.promise then:^(id result) {
        called += 1;
        return self.result2;
    }] fulfilled:^(id result) {
        XCTAssertEqual(result, self.result2, @"Supplied result should be identical to the previously returned one");
        calledFulfil += 1;
    }] failed:^(NSError *error) {
        XCTFail(@"failed-block shouldn't be called");
    }];

    [deferred fulfil:self.result];
    XCTAssertEqual(nextPromise.state, OMPromiseStateFulfilled, @"Second promise should be fulfilled");
    XCTAssertEqual(nextPromise.result, self.result2, @"Final result should be the last returned one");
    XCTAssertEqual(called, 1, @"then-block should have been called exactly once");
    XCTAssertEqual(calledFulfil, 1, @"fulfilled-block should have been called exactly once");
}

- (void)testRescueReturnPromise {
    OMDeferred *deferred = [OMDeferred deferred];

    __block int called = 0, calledProgress = 0, calledFulfil = 0, calledFail = 0;
    OMDeferred *nextDeferred = [OMDeferred deferred];
    OMPromise *nextPromise = [[[deferred.promise rescue:^(NSError *error) {
        XCTAssertEqual(error, self.error, @"Supplied error should be identical to the one passed to fail:");
        called += 1;
        return nextDeferred.promise;
    }] progressed:^(float progress) {
        float progressValues[] = {.5f, 1.f};
        XCTAssertEqualWithAccuracy(progress, progressValues[calledProgress], FLT_EPSILON, @"incorrect progress value");
        calledProgress += 1;
    }] fulfilled:^(id result) {
        XCTAssertEqual(result, self.result2, @"Supplied result should be identical to the one passed to fulfil:");
        calledFulfil += 1;
    }];
    
    [[[nextPromise then:^(id result) {
        return [OMPromise promiseWithError:self.error];
    }] then:^(id result) {
        XCTFail(@"On error then should short circuit");
        return result;
    }] failed:^(NSError *error) {
        XCTAssertEqual(error, self.error, @"Supplied error should be identical to previous error in chain");
        calledFail += 1;
    }];

    [deferred fail:self.error];
    XCTAssertEqual(nextPromise.state, OMPromiseStateUnfulfilled, @"Second promise should not be fulfilled yet");
    XCTAssertEqual(called, 1, @"rescue-block should have been called exactly once");

    [nextDeferred progress:.5f];
    [nextDeferred fulfil:self.result2];
    XCTAssertEqual(nextPromise.state, OMPromiseStateFulfilled, @"Second promise should be fulfilled");
    XCTAssertEqual(calledProgress, 2, @"progressed-block should have been called exactly twice");
    XCTAssertEqual(calledFulfil, 1, @"fulfilled-block should have been called exactly once");
    XCTAssertEqual(calledFail, 1, @"failed-block should have been called exactly once");
}

- (void)testRescueReturnValue {
    OMDeferred *deferred = [OMDeferred deferred];

    __block int called = 0, calledFulfil = 0;
    OMPromise *nextPromise = [[[deferred.promise rescue:^(NSError *error) {
        called += 1;
        return self.result;
    }] fulfilled:^(id result) {
        XCTAssertEqual(result, self.result, @"Supplied result should be identical to the previously returned one");
        calledFulfil += 1;
    }] failed:^(NSError *error) {
        XCTFail(@"failed-block shouldn't be called");
    }];

    [deferred fail:self.error];
    XCTAssertEqual(nextPromise.state, OMPromiseStateFulfilled, @"Second promise should be fulfilled");
    XCTAssertEqual(nextPromise.result, self.result, @"Final result should be the last returned one");
    XCTAssertEqual(called, 1, @"rescue-block should have been called exactly once");
    XCTAssertEqual(calledFulfil, 1, @"fulfilled-block should have been called exactly once");
}

#pragma mark Combinators

- (void)testChainEmptyArray {
    OMPromise *chain = [OMPromise chain:@[] initial:self.result];
    XCTAssertEqual(chain.state, OMPromiseStateFulfilled, @"Chain promise should be fulfilled");
    XCTAssertEqual(chain.result, self.result, @"Chain promise should have the initial result");
}

- (void)testChainFulfil {
    OMDeferred *deferred = [OMDeferred deferred];

    OMPromise *chain = [OMPromise chain:@[
        ^id(id result) {
            return result;
        }, ^id(id result) {
            return deferred.promise;
        }
    ] initial:self.result];

    XCTAssertEqual(chain.state, OMPromiseStateUnfulfilled, @"Chain should be unfulfilled");
    XCTAssertEqualWithAccuracy(chain.progress, .5f, FLT_EPSILON, @"Chain should be have way done");

    [deferred progress:.5f];
    XCTAssertEqualWithAccuracy(chain.progress, .75f, FLT_EPSILON, @"Assuming equal distribution of work load");

    [deferred fulfil:self.result2];
    XCTAssertEqual(chain.state, OMPromiseStateFulfilled, @"Chain should be fulfilled");
    XCTAssertEqual(chain.result, self.result2, @"Chain should have result of last promise in chain");
    XCTAssertEqualWithAccuracy(chain.progress, 1.f, FLT_EPSILON, @"Chain should be done");
}

- (void)testChainFail {
    OMDeferred *deferred = [OMDeferred deferred];

    OMPromise *chain = [OMPromise chain:@[
        ^id(id result) {
            return deferred.promise;
        }, ^id(id result) {
            XCTFail(@"Chain should short-circuit in case of failure");
            return nil;
        }
    ] initial:self.result];

    [deferred progress:.5f];
    XCTAssertEqual(chain.state, OMPromiseStateUnfulfilled, @"Chain should be unfulfilled");
    XCTAssertEqualWithAccuracy(chain.progress, .25f, FLT_EPSILON, @"Chain should be have way done");

    [deferred fail:self.error];
    XCTAssertEqual(chain.state, OMPromiseStateFailed, @"Chain should have failed");
    XCTAssertEqual(chain.error, self.error, @"Chain error should be equal to promise error");
    XCTAssertEqualWithAccuracy(chain.progress, .25f, FLT_EPSILON, @"Chain should be have way done");
}

- (void)testAnyEmptyArray {
    OMPromise *any = [OMPromise any:@[]];
    XCTAssertEqual(any.state, OMPromiseStateFailed, @"Any without any promise should have failed");
    XCTAssertTrue([any.error.domain isEqualToString:OMPromisesErrorDomain], @"Error should be combinator specific");
    XCTAssertEqual(any.error.code, OMPromisesCombinatorAnyNonFulfilledError, @"Error should be combinator specific");
}

- (void)testAnyFulfil {
    OMDeferred *deferred1 = [OMDeferred deferred];
    OMDeferred *deferred2 = [OMDeferred deferred];
    OMDeferred *deferred3 = [OMDeferred deferred];

    OMPromise *any = [OMPromise any:@[deferred1.promise, deferred2.promise, deferred3.promise]];

    [deferred1 progress:.5f];
    XCTAssertEqualWithAccuracy(any.progress, .5f, FLT_EPSILON, @"Any should be have way done");

    [deferred2 progress:.75f];
    XCTAssertEqualWithAccuracy(any.progress, .75f, FLT_EPSILON, @"Any should be nearly done");

    [deferred1 fail:self.error];
    XCTAssertEqual(any.state, OMPromiseStateUnfulfilled, @"Any should be unfulfilled");

    [deferred2 fulfil:self.result];
    XCTAssertEqual(any.state, OMPromiseStateFulfilled, @"Any should be fulfilled");
    XCTAssertEqual(any.result, self.result, @"Result should be identical to the ony supplied by the fulfilled promise");

    XCTAssertNoThrow([deferred3 fulfil:self.result2], @"Another fulfilled promise should have no influence");
    XCTAssertEqual(any.state, OMPromiseStateFulfilled, @"State should be unchanged");
    XCTAssertEqual(any.result, self.result, @"Result should be unchanged");
}

- (void)testAnyFail {
    OMDeferred *deferred1 = [OMDeferred deferred];
    OMDeferred *deferred2 = [OMDeferred deferred];

    OMPromise *any = [OMPromise any:@[deferred1.promise, deferred2.promise]];

    [deferred1 progress:.5f];
    XCTAssertEqualWithAccuracy(any.progress, .5f, FLT_EPSILON, @"Any should be have way done");

    [deferred1 fail:self.error];
    XCTAssertEqual(any.state, OMPromiseStateUnfulfilled, @"Any should be unfulfilled");
    [deferred2 fail:self.error];
    XCTAssertEqual(any.state, OMPromiseStateFailed, @"Any should have failed");
    XCTAssertTrue([any.error.domain isEqualToString:OMPromisesErrorDomain], @"Error should be combinator specific");
    XCTAssertEqual(any.error.code, OMPromisesCombinatorAnyNonFulfilledError, @"Error should be combinator specific");
}

- (void)testAllEmptyArray {
    OMPromise *all = [OMPromise all:@[]];
    XCTAssertEqual(all.state, OMPromiseStateFulfilled, @"An empty set of promises should lead to fulfilled");
    XCTAssertTrue([all.result isEqualToArray:@[]], @"Result should be an empty array");
}

- (void)testAllFulfil {
    OMDeferred *deferred = [OMDeferred deferred];

    OMPromise *all = [OMPromise all:@[deferred.promise, [OMPromise promiseWithResult:self.result]]];

    XCTAssertEqual(all.state, OMPromiseStateUnfulfilled, @"All should be unfulfilled");
    XCTAssertEqualWithAccuracy(all.progress, .5f, FLT_EPSILON, @"All should be have way done");

    [deferred progress:.5f];
    XCTAssertEqualWithAccuracy(all.progress, .75f, FLT_EPSILON, @"All should be nearly done");

    [deferred fulfil:self.result2];
    XCTAssertEqual(all.state, OMPromiseStateFulfilled, @"All should be fulfilled");
    XCTAssertEqualWithAccuracy(all.progress, 1.f, FLT_EPSILON, @"All should be done");
    XCTAssertTrue([all.result isEqualToArray:(@[self.result2, self.result])], @"Result should be an array containing all results");
}

- (void)testAllFail {
    OMDeferred *deferred1 = [OMDeferred deferred];
    OMDeferred *deferred2 = [OMDeferred deferred];

    OMPromise *all = [OMPromise all:@[deferred1.promise, [OMPromise promiseWithResult:self.result], deferred2.promise]];

    [deferred1 progress:.5f];
    XCTAssertEqualWithAccuracy(all.progress, .5f, FLT_EPSILON, @"All should be half way done");
    
    [deferred1 fail:self.error];
    XCTAssertEqual(all.state, OMPromiseStateFailed, @"All should have failed");
    XCTAssertEqual(all.error, self.error, @"Error should be identical to first first failed promises one");

    [deferred2 progress:.5f];
    XCTAssertEqualWithAccuracy(all.progress, .5f, FLT_EPSILON, @"All progress shouldn't change anymore");

    [deferred2 fulfil:self.result];
    XCTAssertEqual(all.state, OMPromiseStateFailed, @"All should have failed");
}

@end
