module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  MediaPlayerDevice = require('./MediaPlayerDevice')(env)
  MediaPlayerController = require('castv2-client').Client
  MediaPlayerReceiver = require('castv2-client').DefaultMediaReceiver
    
  class ChromecastMediaPlayerDevice extends MediaPlayerDevice
    
    constructor: (@config, lastState, @_listener, @debug = false) ->
      @base = commons.base @, "ChromecastMediaPlayerDevice"
      
      @id = @config.id
      @name = @config.name
      
      @_controller = null
      @_receiver = null
      @_player = null
      
      super(lastState)
      
    destroy: -> super()
    
    playAudio: (url, timestamp = 0) =>
      return new Promise( (resolve, reject) =>
        @_pauseUpdates = true
        
        controller = @_getController()
        controller.on('error', (error) => return @_onError(error) )
        
        controller.connect(@_host, () =>
          
          receiver = MediaPlayerReceiver
          receiver.on('error', (error) => return @_onError )
          receiver.on('status', (status) =>
            @base.debug __("Network media player: %s", status)
          )
          
          controller.launch(receiver, (error, player) =>
            return @_onError(error) if error?
              
            @_player = player
            opts = { autoplay: true, currentTime: timestamp }
            content = { contentId: url, contentType: mediatype }
            
            player.load(content, opts, (error) => return @_onError(error) if error? )
          )
        )
      )
      .catch( (error) =>
        @_pauseUpdates = false
        @base.resetLastError()
        @base.rejectWithErrorString Promise.reject, error
      )
    
    _onError: (error) =>
      @stop()
      @_pauseUpdates = false
      
      @base.debug __("Network media player: error")
      @emit('error', error)
      
      return @base.rejectWithErrorString( Promise.reject, error, __("Media player error during playback of: %s", url) )
    
    stop: () =>
      
      @_player.stop() if @_player?
      @_player = null
      @_receiver = null
      @_controller = null
    
    _getController: () =>
      return @_controller if @_controller?
      
      @_controller = new MediaPlayerController()
      
      return @_controller
    
  return ChromecastMediaPlayerDevice