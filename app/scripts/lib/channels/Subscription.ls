module.exports = class Subscription
  (@channel, @handler, @once = false) ->
    if typeof @handler isnt \function then throw new TypeError "Handler should be a function, not #{typeof @handler}"
    @_resub!

  _unsub: ~>
    @channel._unsub @handler
    @_subscribed = false
  _resub: ~>
    @channel._sub @handler, @once
    @_subscribed = true

  unsubscribe: ~>
    if @_subscribed then @_unsub!
    else throw new Error 'Subscription already unsubscribed!'
  subscribe: ~>
    unless @_subscribed then @_resub!
    else throw new Error 'Subscription already subscribed!'

  pause: ~> if @_subscribed then @_unsub!
  resume: ~> unless @_subscribed then @_resub!
