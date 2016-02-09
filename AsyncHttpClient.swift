//
//  AsyncHttpClient.swift
//
//  Created by Orion Edwards on 8/02/16.
//  Copyright © 2016 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation

/** Low level HTTP client used by StockFighterApiClient and StockFighterGmClient. You should probably use those instead */
class AsyncHttpClient : NSObject, NSURLSessionDelegate, NSURLSessionDataDelegate {
    let queue:dispatch_queue_t
    private let _baseUrl:NSURL
    private let _httpHeaders:[String:String]
    
    lazy private var _session:NSURLSession = {
        let sessionConfig = NSURLSessionConfiguration.defaultSessionConfiguration()
        sessionConfig.HTTPAdditionalHeaders = self._httpHeaders
        let nsQueue = NSOperationQueue()
        nsQueue.underlyingQueue = self.queue // deliver on the given queue
        
        return NSURLSession(configuration: sessionConfig, delegate: self, delegateQueue: nsQueue)
        // we must invalidate the session at some point or we leak
    }()
    
    /** Inits the HttpClient
     
     - Parameter baseUrlString: The base URL which will be prepended to all other relative paths. Probably `"https://api.stockfighter.io/ob/api/"`
     - Parameter httpHeaders: HTTP headers to set for each request. Probably `["X-Starfighter-Authorization": yourApiKey]` */
    init(queue: dispatch_queue_t, baseUrlString:String, httpHeaders:[String:String]) {
        guard let url = NSURL(string: baseUrlString) else { fatalError("invalid baseUrl \(baseUrlString)") }
        self.queue = queue
        _baseUrl = url
        _httpHeaders = httpHeaders
    }
    
    /** Performs a synchronous HTTP GET request.
     The response body will both be converted from JSON using `NSJSONSerialization`
     
     - Parameter path: The relative path of the URL to post to e.g. "venues/stocks/etc"
     - Returns: The response from the server deserialized via `NSJSONSerialization.JSONObjectWithData`
     - Throws: An NSError from JSON de/serialization or an error from `HttpErrors`  */
    @warn_unused_result
    func get(path:String) -> Observable<AnyObject>  {
        return sendRequest(NSURLRequest(URL: urlForPath(path)))
    }
    
    /** Performs a synchronous HTTP POST request.
     The request and response body will both be converted to/from JSON using `NSJSONSerialization`
     
     - Parameter path: The relative path of the URL to post to e.g. "venues/stocks/etc"
     - Parameter body: Optional request body - usually `[String:AnyObject]`. If set, will pass into `NSJSONSerialization.dataWithJSONObject` to serialize it
     - Returns: The response from the server deserialized via `NSJSONSerialization.JSONObjectWithData`
     - Throws: An NSError from JSON de/serialization or an error from `HttpErrors` for invalid HTTP response code, etc */
    @warn_unused_result
    func post(path:String, body:AnyObject? = nil) -> Observable<AnyObject> {
        let request = NSMutableURLRequest(URL: urlForPath(path))
        request.HTTPMethod = "POST"
        if let b = body {
            do {
                request.HTTPBody = try NSJSONSerialization.dataWithJSONObject(b, options: NSJSONWritingOptions(rawValue: 0))
            } catch let err {
                return Observable.error(err)
            }
        }
        return sendRequest(request)
    }
    
    /** Performs a synchronous HTTP DELETE request.
     
     - Parameter path: The relative path of the URL to post to e.g. "venues/stocks/etc"
     - Returns: The response from the server deserialized via `NSJSONSerialization.JSONObjectWithData`
     - Throws: An NSError from JSON de/serialization or an error from `HttpErrors`  */
    @warn_unused_result
    func delete(path:String) -> Observable<AnyObject> {
        let request = NSMutableURLRequest(URL: urlForPath(path))
        request.HTTPMethod = "DELETE"
        return sendRequest(request)
    }
    
    private func urlForPath(path:String) -> NSURL {
        if let url = NSURL(string: path, relativeToURL: _baseUrl) {
            return url
        }
        fatalError("Couldn't build a sensible url from \(path)")
    }
    
    @warn_unused_result
    private func sendRequest(request:NSURLRequest) -> Observable<AnyObject> {
        let urlSession = _session
        return Observable.create { observer in
            let task = urlSession.dataTaskWithRequest(request) { (returnedData, urlResponse, anyError) in
                if let err = anyError {
                    observer.onError(err)
                    return
                }
                guard let response = urlResponse as? NSHTTPURLResponse else { fatalError("No response from completed task?") }
                if response.statusCode != 200 {
                    observer.onError(HttpErrors.UnexpectedStatusCode(response.statusCode))
                    return
                }
                guard let data = returnedData else {
                    observer.onError(HttpErrors.NoResponse)
                    return
                }
                
                do {
                    let parsed = try NSJSONSerialization.JSONObjectWithData(data, options: .AllowFragments)
                    observer.onNext(parsed)
                    observer.onCompleted()
                } catch let err {
                    return observer.onError(err)
                }
            }
            task.resume()
            
            return Disposable.create{ [weak task] in
                if let t = task { t.cancel() }
            }
        }
    }
}