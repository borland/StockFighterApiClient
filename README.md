# StockFighterApiClient
I wanted to create a swift client library for [StockFighter](https://www.stockfighter.io/ui/account):

- I wanted to try playing it
- I wanted to use swift, because I really like swift as a language (To me, it gives you efficiency in the ballpark of C++ or Java, but with the nice syntax and conciseness of Ruby, and is safer to use than all of them)
- I wanted to write the library from scratch as a learning/practice exercise
- It's always nice to put more open source code up online to (hopefully) help other people, and help my Resume/CV in future should I ever need that.

If you'd rather code your own libraries, good on you!

If you just want to play StockFighter and don't want to code up your own low level networking/protocol code, feel free to use this library.
It's all under the MIT License so you can pretty much do whatever you'd like with it.

Instructions to add this library to your project can be found below the documentation

# Overview

The client library provides methods to hit all the API methods at https://starfighter.readme.io, and handles JSON serialization, authorization, etc

HTTP requests are done synchronously (they block your calling thread until they return); I may switch this to async in future but to get started synchronous requests are easier

Access to the WebSocket endpoints is also provided, using [SocketRocket](https://github.com/square/SocketRocket) to do the heavy lifting. As you'll see in the Build Instructions, most of the work to set up the library is just to link in the SocketRocket framework

The client library is designed to be simple and easy to use. As such, methods have descriptive names, and inputs are all just method parameters.
There's no "command objects" or "transaction objects" or such things as I think they add unneccessary complexity at this level.

Methods typically will return a response struct which will have public properties for each piece of data

# Using the Api Client

0. Get your StockFighter API key from the SF website, and save it into a text file. I called mine `persistent_key`.  Then add an entry to your `.gitignore` (or similar) to tell it not to track that file so you don't check your API key and publish it to github. You don't need to do this step as you can just pass your api key in as a string, but it's a good idea.

#### Create an instance of `StockFighterApiClient`

    let client = try! StockFighterApiClient(keyFile: "/path/to/keyfile")
	
You can then test it out by calling the `heartbeat` method

    let response = client.heartbeat()
    print(response)
	
You should see `ApiHeartbeatResponse(ok: true, error: "")` in the XCode console

#### Interact with a venue
Most of the things in StockFighter are stock trades on a stock exchange. StockFighter calls these venues. To interact with one, call the `venue` method to get a `Venue` object, and interact from there.

    let testEx = client.venue(account: "TESTACCOUNT", name: "TESTEX")
    print(testEx.heartbeat())
	
You should see `VenueHeartbeatResponse(ok: true, venue: "TESTEX")` in the XCode console

#### List stocks

    let stocks = try testEx.stocks()
    
StocksResponse is

	struct StocksResponse {
	    let ok:Bool
	    let symbols:[Stock]
	}
	
Stock is 

	struct Stock {
	    let name:String
	    let symbol:String
	}
	
#### Get the full order book for a stock
You probably want to get quotes instead, or use the websocket, but if you want to get the current order book you call

    let orders = try testEx.orderBookForStock("FOOBAR")
    print(orders)

#### Get a quote for a stock

    let quote = try testEx.quoteForStock("FOOBAR")
    print(quote)

# Build Instructions:

#### 1. Copy files
You can either use a git submodule to bring in all these files into your project directory, or just copy/paste them.
You'll need:

 - StockFighterApiClient.swift
 - HttpClient.swift
 - WebSocketClient.swift
 - Utils.swift
 - SocketRocket.framework
 - *(optional)* StockFighterGmClient.swift
 
You only need `StockFighterGmClient.swift` If you want to use the GameMaster API to programatically stop/start levels etc.

#### 2. Add to XCode
Drag and drop those files from the finder into your xcode project

#### 3. Check Build Phases
Go to the config for your application's Target (click on the root of the XCode file browser), then go to the **Build Phases** tab

Dragging and dropping in `SocketRocket.framework` should have added an entry for it under **Link Binary with Libraries**.
If there's not one there, add it.

You'll also need to add an entry for it under the **Copy Files**, which will not be present by default

1. Expand the **Copy Files** triangle
2. Change the **Destination** dropdown list to select **Frameworks**
3. Click the **+** Button and select `SocketRocket.framework`

#### 4. Add to Framework Search Paths
Still under your application's Target configuration, go to the **Build Settings** tab

Scroll down to **Framework Search Paths** and put the folder containing SocketRocket.framework in there.
If you double click on it to see the relative path, it should be something like ``"$(SRCROOT)/StockFighter/StockFighterApiClient"``

Now you should be all good to go!

###Note about SocketRocket:

This library uses SocketRocket for WebSocket connections. To make this easy I downloaded the latest
SocketRocket distribution, extracted the Mac OS X (x64) framework, and put it in here.

The OSX SocketRocket hasn't been updated in a while, and as such
 - The SocketRocket header files didn't have any nullability annotations for swift
 - There was no swift module map
 
I've fixed both of those things so SocketRocket could be pulled in nicely without any Objective-C bridging headers, etc.
Will look at sending those fixes upstream at some point
