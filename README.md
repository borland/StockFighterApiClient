# StockFighterApiClient

This is a client library written in swift for [StockFighter](https://www.stockfighter.io/ui/account):

Instructions to add this library to your project can be found below the documentation

The client library provides methods to hit all the API methods at https://starfighter.readme.io, and handles JSON serialization, authorization, etc

Access to the WebSocket endpoints is also provided, using [SocketRocket](https://github.com/square/SocketRocket) to do the heavy lifting. As you'll see in the Build Instructions, most of the work to set up the library is just to link in the SocketRocket framework

**Design**

The client library is designed to be simple and easy to use. As such, methods have descriptive names, and inputs are all just method parameters.
There's no "command objects" or "transaction objects" or such things as I think they add unneccessary complexity at this level.

Methods typically will return a response struct which will have public properties for each piece of data, which you can then access.

Swift exceptions are used for things that might fail in important ways (Network error, unparseable JSON, StockFighter servers return a response). They're not used for trivial things (missing JSON element on an otherwise OK response). Generally you can just surround your main code with a do/catch and log any exceptions. In the normal case you won't get any.

HTTP requests are done synchronously (they block your calling thread until they return); I may switch this to async in future but to get started synchronous requests are easier.

**Why write this?**
- I wanted to try playing StockFighter
- I wanted to use swift, because I really like swift as a language
- I wanted to write the library from scratch as a learning/practice exercise
- It's always nice to put more open source code up online to (hopefully) help other people, and help my Resume/CV in future should I ever need that.

If you just want to play StockFighter and don't want to code up your own low level networking/protocol code, feel free to use this library.
It's all under the MIT License so you can pretty much do whatever you'd like with it.

If you'd rather code your own libraries, good on you!

# Using the Api Client

Get your StockFighter API key from the SF website, and save it into a text file. I called mine `persistent_key`.  Then add an entry to your `.gitignore` (or similar) to tell it not to track that file so you don't check your API key and publish it to github. You don't need to do this step as you can just pass your api key in as a string, but it's a good idea.

**Common Enums:**
You'll run into these as they're used in quite a few places.
`OrderDirection` is self-explanatory, while `OrderType` is explained at https://starfighter.readme.io/docs/place-new-order#order-types

	enum OrderDirection {
	    case Buy, Sell
	}

	enum OrderType {
	    case Market, Limit, FillOrKill, ImmediateOrCancel
	}
    

**Errors:**
All the methods can throw either an `NSError` returned from the underlying NSURLSession, or from JSON parsing, or they can throw

- `ApiErrors.ServerError(String)` if the server returned ok: false with some error message (which will be available in the String)
- `ApiErrors.UnexpectedJson(String)` if the server returned some JSON the client can't deal with
- `ApiErrors.CantParseDate(String)` if the server returned an unparseable DateTime string
- `ApiErrors.CantParseEnum(String, String)` if the server returned a string value which can't be mapped to an enum (e.g. unknown OrderType)

Now let's get going

#### Create an instance of `StockFighterApiClient`

    let client = try! StockFighterApiClient(keyFile: "/path/to/keyfile")
	
You can then test it out by calling the [`heartbeat` method](https://starfighter.readme.io/docs/heartbeat)

    let response = client.heartbeat()
    print(response)
	
You should see `ApiHeartbeatResponse(ok: true, error: "")` in the XCode console.

**Errors**:
This method can throw 

- `ClientErrors.CantReadKeyFile` if the keyFile can't be found
- `ClientErrors.KeyFileInvalidFormat` if the keyFile doesn't contain readable UTF-8 text

Both of these should probably be considered fatal errors, hence I've used `try!` in the example above

#### Interact with a venue
Most of the things in StockFighter are stock trades on a stock exchange. StockFighter calls these venues. To interact with one, call the `venue` method to get a `Venue` object, and interact from there.

You can call the venue's [`heartbeat` method](https://starfighter.readme.io/docs/heartbeat) to see if it's alive

    let testExchange = client.venue(account: "EXB123456", name: "TESTEX")
    print(testExchange.heartbeat())
	
You should see `VenueHeartbeatResponse(ok: true, venue: "TESTEX")` in the XCode console

#### Stocks on a Venue [(SF Documentation)](https://starfighter.readme.io/docs/list-stocks-on-venue)

    let stocks = try testExchange.stocks()
    
    // stocks is a StocksResponse, which is:
	struct StocksResponse {
	    let ok:Bool
	    let symbols:[Stock]
	}
	
    // Stock is:
	struct Stock {
	    let name:String
	    let symbol:String
	}
	
#### Get the full order book for a stock [(SF Documentation)](https://starfighter.readme.io/docs/get-orderbook-for-stock)
You probably want to get quotes instead, or use the websocket, but if you want to get the current order book you call

    let orders = try testExchange.orderBookForStock("FOOBAR")
	
    // orders is an OrderBookResponse, which is:
	struct OrderBookResponse {
	    let ok:Bool
	    let venue:String
	    let symbol:String
	    let bids:[OrderBookOrder]
	    let asks:[OrderBookOrder]
	    let timeStamp:NSDate
	}
	
	// OrderBookOrder is:
	struct OrderBookOrder {
	    let price:Int
	    let qty:Int
	    let isBuy:Bool
	}


#### Place a new order [(SF Documentation)](https://starfighter.readme.io/docs/place-new-order#order-types)

    let order = try testExchange.placeOrderForStock("FOOBAR", price: 100, qty: 10, direction: .Buy)
	
	// order is an OrderResponse, which is:
	struct OrderResponse {
	    let ok:Bool
	    let venue:String
	    let symbol:String
	    let direction:OrderDirection
	    let originalQty:Int
	    let outstandingQty:Int // this is the quantity *left outstanding*
	    let price:Int // the price on the order -- may not match that of fills!
	    let type: OrderType
	    let id:Int // guaranteed unique *on this venue*
	    let account:String
	    let timeStamp:NSDate // ISO-8601 timestamp for when we received order
	    let fills:[OrderFill] // may have zero or multiple fills.
	    let totalFilled:Int
	    let open:Bool
	}
#### Get a quote for a stock

    let quote = try testExchange.quoteForStock("FOOBAR")
    
	// quote is a QuoteResponse, which is:
	struct QuoteResponse {
	    let ok:Bool // true
	    let venue:String // venue identifier
	    let symbol:String // stock symbol
	    let bidBestPrice:Int? // best price currently bid for the stock, which may not be present
	    let askBestPrice:Int? // // best price currently offered for the stock, which may not be present
	    let bidSize:Int // aggregate size of all orders at the best bid
	    let askSize:Int // aggregate size of all orders at the best ask
	    let bidDepth:Int  // aggregate size of *all bids*
	    let askDepth:Int // aggregate size of *all asks*
	    let lastTradePrice:Int // price of last trade
	    let lastTradeSize:Int // quantity of last trade
	    let lastTradeTimeStamp:NSDate // timestamp of last trade
	    let quoteTimeStamp:NSDate // ts we last updated quote at (server-side)
	}
	
#### Status for an Existing



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

#### 4. Add to Framework Search Paths if needed
Still under your application's Target configuration, go to the **Build Settings** tab

Scroll down to **Framework Search Paths** and if there's not an entry for it, put the folder containing SocketRocket.framework in there.
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
