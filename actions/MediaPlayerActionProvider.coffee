module.exports = (env) ->
  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  M = env.matcher
  commons = require('pimatic-plugin-commons')(env)

  class MediaPlayerActionProvider extends env.actions.ActionProvider
    
    constructor: (@framework, @config) ->
      @base = commons.base @, 'MediaPlayerActionProvider'
      @debug = @config.debug

      super()
    
    parseAction: (input, context) =>
      device = null
      file = null
      volume = 40
      
      setVolume = (m) =>
        m.match([" with volume "])
          .matchNumericExpression( (m, v) => volume = v )
      
      setFile = (m, f) => file = f
      setDevice = (m, d) => device = d
      
      devicesWithAction = (f) =>
        _(@framework.deviceManager.devices).values().filter( (device) => 
          device.hasAction(f)
        ).value()
      
      m = M(input, context)
        .match(["play ", "Play "])
        .matchStringWithVars( setFile )
        .match([" via "])
        .matchDevice( devicesWithAction("playAudio"), setDevice)
        .optional(setVolume)
      
      if m.hadMatch()
        match = m.getFullMatch()
        
        return {
          token: match
          nextInput: input.substring(match.length)
          actionHandler: new MediaPlayerActionHandler(@framework, device, file, volume)
        }
      else
        return null
        
  class MediaPlayerActionHandler extends env.actions.ActionHandler
  
    constructor: (@framework, @_device, @_file, @_volume) ->
      @base = commons.base @, 'MediaPlayerActionHandler'
      
      super()
      
    setup: () ->
      @dependOnDevice(@_device)
      super()
    
    executeAction: (simulate) =>
      Promise.join(
        @framework.variableManager.evaluateStringExpression(@_file),
        @framework.variableManager.evaluateNumericExpression(@_volume),
        (file, volume) =>
          if simulate
            return Promise.resolve __("Would play file: \"%s\"", file)
          
          else
            @file = file
            @base.debug __("MediaPlayerActionHandler - Device: '%s', file: '%s'", @_device.id, file)
            
            return @_device.playAudio(file, null, volume)
            .then( (result) =>
              return Promise.resolve __("File: %s was played succesfully", file)
            )
            .catch( (error) =>
              return Promise.reject error
            )
      )
      .catch( (error) =>
        return Promise.resolve __("There were error(s) playing file: %s", @file)
      )
    
    destroy: () ->
      super()
  
  return MediaPlayerActionProvider
  
  