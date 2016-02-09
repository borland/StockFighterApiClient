//
//  MiniRxSwift.swift
//
//  Created by Orion Edwards on 8/02/16.
//  Copyright © 2016 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//
// Implements a minimal subset of the Reactive framework (should be compatible with RxSwift)
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

/** Swift doesn't allow equality checking of closures, so we assign an arbitrary id to observers so we can compare/remove them */
private var _anyObserverIdCounter:Int32 = 0

/** Type-Erasing bridge between Observer protocol and a class we can stick in a collection:
 http://krakendev.io/blog/generic-protocols-and-their-shortcomings */
class Observer<T> : ObserverType, Equatable {
    typealias ValueType = T
    
    private let _id:Int32
    
    private let _onNext: (T throws -> Void)
    private let _onError: (ErrorType -> Void)
    private let _onCompleted: (Void -> Void)
    
    /** Create an anonymous observer wrapping up to 3 closures */
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
    
    /** Create an anonymous observer wrapping an existing ObserverType. This is needed to bridge between protocols and generics */
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
// our Observer wrapper supports equality so we can remove them from arrays
func ==<T>(lhs:Observer<T>, rhs:Observer<T>) -> Bool {
    return lhs._id == rhs._id
}

/** Type-Erasing bridge between Observable protocol and a class we can stick in a variable */
class Observable<T> : ObservableType {
    typealias ValueType = T
    
    private let _subscribe: (Observer<T> -> DisposableType)
    
    /** Init with a closure */
    required init(subscribe: (Observer<T> -> DisposableType)) {
        _subscribe = subscribe
    }
    /** Init by wrapping ObservableType (bridge between protocols and generics) */
    required init<O : ObservableType where O.ValueType == T>(_ observable:O) {
        _subscribe = observable.subscribe
    }
    func subscribe<O : ObserverType where O.ValueType == ValueType>(observer: O) -> DisposableType {
        return _subscribe(Observer(observer))
    }
    
    /** Creates a new observable by calling your closure to perform some operation:
    http://www.introtorx.com/content/v1.0.10621.0/04_CreatingObservableSequences.html#ObservableCreate */
    @warn_unused_result
    static func create(subscribe: (Observer<T> -> DisposableType)) -> Observable<T> {
        return Observable(subscribe: subscribe)
    }
    
    /** Creates a new observable which returns the given error:
    http://www.introtorx.com/content/v1.0.10621.0/04_CreatingObservableSequences.html#ObservableThrow */
    @warn_unused_result
    static func error(err:ErrorType) -> Observable<T> {
        var disposed = false
        
        return create{ observer in
            if !disposed {
                observer.onError(err)
            }
            return AnonymousDisposable{
                disposed = true
            }
        }
    }
    
    /** Creates a new observable which completes immediately with no value:
    http://www.introtorx.com/content/v1.0.10621.0/04_CreatingObservableSequences.html#ObservableEmpty */
    @warn_unused_result
    static func empty() -> Observable<T> {
        return create{ observer in
            observer.onCompleted()
            return AnonymousDisposable{ _ in }
        }
    }
    
    /** Creates a new observable which immediately returns the provided value, then completes:
    http://www.introtorx.com/content/v1.0.10621.0/04_CreatingObservableSequences.html#ObservableReturn */
    @warn_unused_result
    static func just(value:T) -> Observable<T> {
        return create{ observer in
            observer.onNext(value)
            observer.onCompleted()
            return AnonymousDisposable{ _ in }
        }
    }
}

/** Represents an Event Source that you can use to publish values:
http://www.introtorx.com/content/v1.0.10621.0/02_KeyTypes.html#Subject */
class Subject<T> : ObserverType, ObservableType {
    typealias ValueType = T
    private var _subscribers:[Observer<T>] = []
    
    func subscribe<O : ObserverType where O.ValueType == T>(observer: O) -> DisposableType {
        let wrapper = Observer(observer)
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
    func asObservable() -> Observable<ValueType> {
        return Observable(self)
    }
    func subscribe() {
        subscribe(Observer(next: { _ in }))
    }
    func subscribeNext(next:(ValueType throws -> Void)) {
        subscribe(Observer(next: next))
    }
    func subscribeError(error:(ErrorType) -> Void ) {
        subscribe(Observer(error: error))
    }
    func subscribeCompleted(completed:() -> Void ) {
        subscribe(Observer(completed: completed))
    }
    func subscribeNext(next:(ValueType) -> Void, error:(ErrorType) -> Void) {
        subscribe(Observer(next: next, error: error))
    }
    func subscribeNext(next:(ValueType) -> Void, error:(ErrorType) -> Void, completed:() -> Void) {
        subscribe(Observer(next: next, error: error, completed: completed))
    }
}

private class AnonymousDisposable : DisposableType {
    private let _dispose:(Void -> Void)
    
    required init(dispose:(Void -> Void)) {
        _dispose = dispose
    }
    func dispose() {
        _dispose()
    }
}

class Disposable {
    static func create(dispose:(Void->Void)) -> DisposableType {
        return AnonymousDisposable(dispose: dispose)
    }
}

class CompositeDisposable : DisposableType {
    private var _disposables:[DisposableType] = []
    private var _disposed = false
    
    init() { }
    
    init(disposables:[DisposableType]) {
        _disposables.appendContentsOf(disposables)
    }
    
    func add(disposable:DisposableType) {
        lock(self) {
            if _disposed {
                disposable.dispose()
                return
            }
            _disposables.append(disposable)
        }
    }
    
    func dispose() {
        let copy:[DisposableType] = lock(self) {
            _disposed = true
            return _disposables
        }
        for d in copy { d.dispose() }
    }
}

class SerialDisposable : DisposableType {
    private var _disposable:DisposableType?
    private var _disposed = false
    init() {}
    
    init(disposable:DisposableType) {
        _disposable = disposable
    }
    
    var disposable:DisposableType? {
        get { return _disposable }
        set {
            if let old:DisposableType = lock(self, block: {
                let x = _disposable
                _disposable = newValue
                return x
            }) {
                old.dispose()
            }
        }
    }
    
    func dispose() {
        if let copy:DisposableType = lock(self, block: {
            let x = _disposable
            _disposable = nil
            return x
        }) {
            copy.dispose()
        }
    }
}

/** Linq */
extension ObservableType {
    
    // untested
    @warn_unused_result
    func map<R>(transform: (ValueType throws -> R)) -> Observable<R> {
        return Observable.create { observer in
            self.subscribe(Observer( // TODO why must we wrap this in AnyObserver?
                next: { (value) -> Void in
                    do {
                        observer.onNext(try transform(value))
                    } catch let error {
                        observer.onError(error)
                    }
                },
                error: observer.onError,
                completed: observer.onCompleted))
        }
    }
    
    // untested
    @warn_unused_result
    func flatMap<T:ObservableType, R where T.ValueType == R>(transform: (ValueType throws -> T)) -> Observable<R> {
        return Observable.create { observer in
            let group = CompositeDisposable()
            var count:Int32 = 1
            let completionHandler = {
                let newCount = OSAtomicDecrement32(&count)
                if newCount == 0 { // all done
                    observer.onCompleted()
                }
            }
            
            group.add(self.subscribe(Observer( // TODO why must we wrap this in AnyObserver?
                next: { (value) -> Void in
                    do {
                        OSAtomicIncrement32(&count)
                        let innerDisposable = (try transform(value)).subscribe(Observer(
                            next: { (v) in
                                observer.onNext(v)
                            },
                            error: { err in
                                group.dispose()
                                observer.onError(err)
                            },
                            completed: completionHandler))
                        group.add(innerDisposable)
                        
                    } catch let error {
                        group.dispose()
                        observer.onError(error)
                    }
                },
                error: observer.onError,
                completed: completionHandler)))
            
            return group
        }
    }
    
    // untested
    @warn_unused_result
    func filter(predicate: (ValueType throws -> Bool)) -> Observable<ValueType> {
        return Observable.create { (observer) -> DisposableType in
            self.subscribe(Observer( // TODO why must we wrap this in AnyObserver?
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
        }
    }
}
