//
//  Utils.swift
//
//  Created by Orion Edwards on 25/01/16.
//  Copyright © 2016 Orion Edwards. Licensed under the MIT License
//  https://opensource.org/licenses/MIT
//

import Foundation

/** Swift variant of C#'s lock statement which calls `objc_sync_enter` and guarantees to call `objc_sync_exit`
- Parameter object: The object to lock.
- Paremeter block: Code to run while the lock is acquired */
func lock<T>(object:AnyObject, @noescape _ block:() throws -> T) rethrows -> T {
    objc_sync_enter(object)
    defer{ objc_sync_exit(object) }
    
    return try block()
}