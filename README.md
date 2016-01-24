# Build Instructions:

#### 1. Add Files to your project
You can either use a git submodule to bring in all these files into your project, or just copy/paste them.
You'll need:

 - 

2. 


##Note about SocketRocket:

This library uses SocketRocket for WebSocket connections. To make this easy I downloaded the latest
SocketRocket distribution, extracted the Mac OS X (x64) framework, and put it in here.

The OSX SocketRocket hasn't been updated in a while, and as such
 - The SocketRocket header files didn't have any nullability annotations for swift
 - There was no swift module map
 
I've fixed both of those things so SocketRocket could be pulled in nicely without any Objective-C bridging headers, etc.
Will look at sending those fixes upstream at some point
