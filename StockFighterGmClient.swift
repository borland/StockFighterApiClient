//
//  StockFighterGmClient.swift
//
//  Created by Orion Edwards on 25/01/16.
//  Copyright © 2016 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//


import Foundation

/** This class handles interaction with the GameMaster API as documented at 
https://discuss.starfighters.io/t/the-gm-api-how-to-start-stop-restart-resume-trading-levels-automagically/143 */
class StockFighterGmClient {
    private let _httpClient:HttpClient
    
    /** Inits the client with a file containing your API key.
     This is good because you can put your API key in a separate file, reference it here, but EXCLUDE that file from source control
     as you don't want to be publishing your API key on GitHub (even though StockFighter is just a game)
     
     - Parameter keyFile: Path to a text file which contains your API key */
    convenience init(keyFile:String) throws {
        guard let keyData = NSFileManager.defaultManager().contentsAtPath(keyFile) else {
            throw ClientErrors.CantReadKeyFile
        }
        guard let key = NSString(data: keyData, encoding: NSUTF8StringEncoding) as? String else {
            throw ClientErrors.KeyFileInvalidFormat
        }
        self.init(apiKey: key)
    }
    
    /** Inits the client with your API key. You should probably call `init(keyFile)` instead of this
     - Parameter apiKey: Your API key */
    init(apiKey:String) {
        _httpClient = HttpClient(baseUrlString:"https://api.stockfighter.io/gm/", httpHeaders: ["Cookie": "api_key=\(apiKey)"])
    }
    
    /** Starts a level
    - Parameter level: The underscored level name e.g. "first_steps"
    - Throws: An NSError from JSON deserialization or an error from `HttpErrors` for invalid HTTP response code, etc */
    func startLevel(level:String) throws -> StartLevelResponse {
        let d = try _httpClient.post("levels/\(level)") as! [String:AnyObject]
        return try StartLevelResponse(dictionary: d)
    }
    
    func getLevelInstance(instanceId:Int) throws -> LevelStatus {
        let d = try _httpClient.get("instances/\(instanceId)") as! [String:AnyObject]
        return LevelStatus(dictionary: d)
    }

    /** Restarts a level
    - Parameter instanceId: The instanceId you got when you called startLevel
    - Throws: An error from `HttpErrors` for invalid HTTP response code, etc */
    func restartLevelInstance(instanceId:Int) throws {
        try _httpClient.post("instances/\(instanceId)/restart")
    }
    
    /** Stops a level
     - Parameter instanceId: The instanceId you got when you called startLevel
     - Throws: An error from `HttpErrors` for invalid HTTP response code, etc */
    func stopLevelInstance(instanceId:Int) throws {
        try _httpClient.post("instances/\(instanceId)/stop")
    }
    
    /** Stops a level
     - Parameter instanceId: The instanceId you got when you called startLevel
     - Throws: An error from `HttpErrors` for invalid HTTP response code, etc */
    func resumeLevelInstance(instanceId:Int) throws -> StartLevelResponse {
        let d = try _httpClient.post("instances/\(instanceId)/resume")
        return try StartLevelResponse(dictionary: d as! [String : AnyObject])
    }
}

struct StartLevelResponse {
    let ok:Bool
    let account:String
    let instanceId:Int
    let secondsPerTradingDay:Int
    let tickers:[String]
    let venues:[String]
    let balances:[String:Int]
    let instructions: [String:String]
    
    init(dictionary d:[String:AnyObject]) throws {
        ok = d["ok"] as? Bool ?? false
        if let msg = d["error"] as? String where ok == false {
            throw ApiErrors.ServerError(msg)
        }
        
        account = d["account"] as! String
        instanceId = d["instanceId"] as! Int
        secondsPerTradingDay = d["secondsPerTradingDay"] as! Int
        tickers = d["tickers"] as! [String]
        venues = d["venues"] as! [String]
        balances = d["balances"] as? [String:Int] ?? [:]
        instructions = d["instructions"] as? [String:String] ?? [:]
    }
}

struct LevelStatus {
    let ok:Bool
    let done:Bool
    let instanceId:Int
    let state:String
    let tradingDay:Int
    let endOfTheWorldDay:Int
    
    init(dictionary d:[String:AnyObject]) {
        ok = d["ok"] as! Bool
        done = d["done"] as! Bool
        instanceId = d["id"] as! Int
        state = d["state"] as! String
        if let details = d["details"] as? [String:Int] {
            tradingDay = details["tradingDay"] ?? 0
            endOfTheWorldDay = details["endOfTheWorldDay"] ?? 0
        } else {
            tradingDay = 0
            endOfTheWorldDay = 0
        }
    }
}