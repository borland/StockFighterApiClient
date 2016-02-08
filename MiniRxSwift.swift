//
//  MiniRxSwift.swift
//
//  Created by Orion Edwards on 8/02/16.
//  Copyright © 2016 Orion Edwards. All rights reserved.
//
// Implements a minimal subset of the Reactive framework (loosely based on RxSwift but more from my C# background knowledge)
// which lets us write async methods much more nicely

import Foundation

protocol ObserverType {
    typealias ValueType
    
    func onNext(value: ValueType)
    func onCompleted()
    func onError(error:ErrorType)
}

protocol ObservableType {
    typealias ValueType
    func subscribe<O: ObserverType where O.ValueType == ValueType>(observer: O) -> DisposableType
}

protocol DisposableType {
    func dispose()
}

private var _anyObserverIdCounter:Int32 = 0

/** Type-Erasing bridge between Observer protocol and a class we can stick in a collection:
 http://krakendev.io/blog/generic-protocols-and-their-shortcomings */
class AnyObserver<T> : ObserverType, Equatable {
    typealias ValueType = T
    
    private let _id:Int32
    
    private let _onNext: (T throws -> Void)
    private let _onError: (ErrorType -> Void)
    private let _onCompleted: (Void -> Void)
    
    init(next:(T throws -> Void)? = nil, error:(ErrorType -> Void)? = nil, completed:(Void -> Void)? = nil) {
        _id = OSAtomicIncrement32(&_anyObserverIdCounter)
        
        // for some reason the ?? operator doesn't like optional closures
        if let n = next {
            _onNext = n
        } else {
            _onNext = { _ in }
        }
        
        if let e = error {
            _onError = e
        } else {
            _onError = { err in fatalError("unobserved error \(err)") }
        }
        if let c = completed {
            _onCompleted = c
        } else {
            _onCompleted = { _ in }
        }
    }
    
    required init <O: ObserverType where O.ValueType == T>(_ observer:O) {
        _id = OSAtomicIncrement32(&_anyObserverIdCounter)
        _onNext = observer.onNext
        _onError = observer.onError
        _onCompleted = observer.onCompleted
    }
    func onNext(value: T) {
        do {
            try _onNext(value)
        } catch let error {
            _onError(error)
        }
    }
    func onError(error: ErrorType) {
        _onError(error)
    }
    func onCompleted() {
        _onCompleted()
    }
}
// our wrapper also supports equality so we can remove them from arrays
func ==<T>(lhs:AnyObserver<T>, rhs:AnyObserver<T>) -> Bool {
    return lhs._id == rhs._id
}

/** Type-Erasing bridge between Observable protocol and a class we can stick in a variable */
class AnyObservable<T> : ObservableType {
    typealias ValueType = T
    
    private let _subscribe: (AnyObserver<T> -> DisposableType)
    
    /** Init with a closure (basically being an AnonymousObservable) */
    required init(subscribe: (AnyObserver<T> -> DisposableType)) {
        _subscribe = subscribe
    }
    /** Init by wrapping ObservableType (basically being an AnyObservable) */
    required init<O : ObservableType where O.ValueType == T>(_ observable:O) {
        _subscribe = observable.subscribe
    }
    func subscribe<O : ObserverType where O.ValueType == ValueType>(observer: O) -> DisposableType {
        return _subscribe(AnyObserver(observer))
    }
}

/** Thread-safe */
class Subject<T> : ObserverType, ObservableType {
    typealias ValueType = T
    private var _subscribers:[AnyObserver<T>] = []
    
    func subscribe<O : ObserverType where O.ValueType == T>(observer: O) -> DisposableType {
        let wrapper = AnyObserver(observer)
        lock(self) {
            _subscribers.append(wrapper)
        }
        return AnonymousDisposable(dispose: {
            lock(self) {
                if let idx = self._subscribers.indexOf({ $0 == wrapper }) {
                    self._subscribers.removeAtIndex(idx)
                }
            }
        })
    }
    func onNext(value: T) {
        let subscribers = lock(self){ _subscribers } // copy
        for s in subscribers { s.onNext(value) }
    }
    func onError(error: ErrorType) {
        let subscribers = lock(self){ _subscribers } // copy
        for s in subscribers { s.onError(error) }
    }
    func onCompleted() {
        let subscribers = lock(self){ _subscribers } // copy
        for s in subscribers { s.onCompleted() }
    }
}

/** Overloads on subscribe to make it nice to use */
extension ObservableType {
    /** type erasing wrapper */
    @warn_unused_result
    func asObservable() -> AnyObservable<ValueType> {
        return AnyObservable(self)
    }
    func subscribe() {
        subscribe(AnyObserver(next: { _ in }))
    }
    func subscribeNext(next:(ValueType throws -> Void)) {
        subscribe(AnyObserver(next: next))
    }
    func subscribeError(error:(ErrorType) -> Void ) {
        subscribe(AnyObserver(error: error))
    }
    func subscribeCompleted(completed:() -> Void ) {
        subscribe(AnyObserver(completed: completed))
    }
    func subscribeNext(next:(ValueType) -> Void, error:(ErrorType) -> Void) {
        subscribe(AnyObserver(next: next, error: error))
    }
    func subscribeNext(next:(ValueType) -> Void, error:(ErrorType) -> Void, completed:() -> Void) {
        subscribe(AnyObserver(next: next, error: error, completed: completed))
    }
}

class AnonymousDisposable : DisposableType {
    private let _dispose:(Void -> Void)
    
    required init(dispose:(Void -> Void)) {
        _dispose = dispose
    }
    func dispose() {
        _dispose()
    }
}

@warn_unused_result
func createObservable<T>(subscribe: (AnyObserver<T> -> DisposableType)) -> AnyObservable<T> {
    return AnyObservable(subscribe: subscribe)
}

/** Linq */
extension ObservableType {
    
    @warn_unused_result
    func map<R>(transform: (ValueType throws -> R)) -> AnyObservable<R> {
        return createObservable({ (observer) -> DisposableType in
            self.subscribe(AnyObserver( // TODO why must we wrap this in AnyObserver?
                next: { (value) -> Void in
                    do {
                        observer.onNext(try transform(value))
                    } catch let error {
                        observer.onError(error)
                    }
                },
                error: observer.onError,
                completed: observer.onCompleted))
        })
    }
    
    @warn_unused_result
    func filter(predicate: (ValueType throws -> Bool)) -> AnyObservable<ValueType> {
        return createObservable({ (observer) -> DisposableType in
            self.subscribe(AnyObserver( // TODO why must we wrap this in AnyObserver?
                next: { (value) -> Void in
                    do {
                        if try predicate(value) {
                            observer.onNext(value)
                        }
                    } catch let error {
                        observer.onError(error)
                    }
                },
                error: observer.onError,
                completed: observer.onCompleted))
        })
    }
}

class Observable {
    @warn_unused_result
    static func error<T>(err:ErrorType) -> AnyObservable<T> {
        var disposed = false
        
        return createObservable{ observer in
            if !disposed {
                observer.onError(err)
            }
            return AnonymousDisposable{
                disposed = true
            }
        }
    }
    
    @warn_unused_result
    static func empty<T>() -> AnyObservable<T> {
        return createObservable{ observer in
            observer.onCompleted()
            return AnonymousDisposable{ _ in }
        }
    }
}