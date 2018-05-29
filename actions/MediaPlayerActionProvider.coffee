module.exports = (env) ->
  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  M = env.matcher
  commons = require('pimatic-plugin-commons')(env)
  t = env.require('decl-api').types

  class MediaPlayerActionProvider extends env.actions.ActionProvider
    
    constructor: (@framework, @config) ->
      @base = commons.base @, 'MediaPlayerActionProvider'
      @debug = @config.debug

      super()

      return null
  
  class MediaPlayerActionHandler extends env.actions.ActionHandler
  
    constructor: (@framework, @_device, @_ttsSettings) ->
      @base = commons.base @, 'MediaPlayerActionHandler'
      
      super()
      
    setup: () ->      
      super()
    
    executeAction: (simulate) =>
      
      return Promise.resolve true
          
    destroy: () ->
      super()
  
  return MediaPlayerActionProvider
  
  