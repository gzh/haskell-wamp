# haskell-wamp

A very experimental Haskell implementation of the Web Application Messaging Protocol v2 Basic Profile.

Official specification available [here](http://wamp-proto.org/spec/).

For a sample WAMP *Router* using [wai-websockets](https://hackage.haskell.org/package/wai-websockets) see examples.

*Warning:* as of right now this is nothing more than an incomplete rough sketch.

## Stack setup

```bash
stack build
stack runghc wamp-client/test.hs
```

## Nix - Run Example

```bash
cd examples/warp-wamp-router
nix-shell --attr warp-wamp-router.env ../../default
cabal run
```