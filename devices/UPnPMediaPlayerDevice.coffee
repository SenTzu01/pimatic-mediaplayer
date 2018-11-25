module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  MediaPlayerDevice = require('./MediaPlayerDevice')(env)
  MediaPlayerController = require('../lib/MediaPlayerController')(env)
    
  class UPnPMediaPlayerDevice extends MediaPlayerDevice
    
    constructor: (@config, lastState, options, @debug = false) ->
      @id = @config.id
      @name = @config.name
      
      @_listener = options.listener
      @_mediaServer = options.mediaServer
      @_controller = null
      #@on('xml', (xml) => @_controller = @_newController(xml, @debug) )
      
      @_resource = null
      super(lastState)
      
    destroy: -> super()
    
    playAudio: (@_resource, outputDuration, volume = 40) =>
      return new Promise( (resolve, reject) =>
        
        @_debug __("outputDuration: %s", outputDuration)
        
        @_disableUpdates()
        
        @_controller = @_newController(@_xml) if !@_controller?
        @_controller
          .once('playing', ()     => resolve "success" )
          .once('stopped', ()     => @_onStopped() )
          .once('error', (error)  => reject @_errorHandler(error) )
        
        url = @_mediaServer.addResource(@_resource)
        opts = {
          contentType: 'audio/mp3'
          duration: outputDuration
        }
        @_controller.load(url, opts, (error, result) =>
          if error?
            @_debug __("load error - code: %s, message: %s", error.code, error.message)
            Promise.reject error
          
          @_debug result
          
          @_controller.play( (error, result) =>
            if error?
              @_debug __("play error - code: %s, message: %s", error.code, error.message)
              reject error
            @_debug result
            resolve url
          )
        )
      )
      .catch( (error) =>
        @base.rejectWithErrorString( Promise.reject, @_errorHandler(error) )
      )
    
    stop: () =>
      @_controller.stop() if @_controller?
    
    _onStopped: () =>
      @_logStatus( "stopped" )
      @_mediaServer.removeResource(@_resource)
      @_enableUpdates()
      return "success"
    
    _getController: (xml) =>
      controller = new MediaPlayerController(xml, @debug)
        .on("loading", () => @_logStatus( "loading" ) )
        .on("stopped", () => @_logStatus( "stopped" ) )
        .on("paused", ()  => @_logStatus( "paused" ) )
      return controller
    
    _newController: (xml) =>
      @_controller = null
      return @_getController(xml)
  
  return UPnPMediaPlayerDevice