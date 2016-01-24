# StockFighterApiClient
I wanted to create a swift client library for [StockFighter](https://www.stockfighter.io/ui/account):

- I wanted to try playing it
- I wanted to use swift, because I really like swift as a language (To me, it gives you efficiency in the ballpark of C++ or Java, but with the nice syntax and conciseness of Ruby, and is safer to use than all of them)
- I wanted to write the library from scratch as a learning/practice exercise
- It's always nice to put more open source code up online to (hopefully) help other people, and help my Resume/CV in future should I ever need that.

If you'd rather code your own libraries, good on you!

If you just want to play StockFighter and don't want to code up your own low level networking/protocol code, feel free to use this library.
It's all under the MIT License so you can pretty much do whatever you'd like with it.

Documentation, etc coming soon**.**

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

##Note about SocketRocket:

This library uses SocketRocket for WebSocket connections. To make this easy I downloaded the latest
SocketRocket distribution, extracted the Mac OS X (x64) framework, and put it in here.

The OSX SocketRocket hasn't been updated in a while, and as such
 - The SocketRocket header files didn't have any nullability annotations for swift
 - There was no swift module map
 
I've fixed both of those things so SocketRocket could be pulled in nicely without any Objective-C bridging headers, etc.
Will look at sending those fixes upstream at some point
