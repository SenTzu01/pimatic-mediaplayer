module.exports = (env) ->
  
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  Promise = env.require 'bluebird'
  t = env.require('decl-api').types
  net = require('net')
  MediaPlayerDevice = require('./MediaPlayerDevice')(env)
  URL = require('url')
  querystring = require("querystring")
  
  class HeosMediaPlayerDevice extends MediaPlayerDevice
    _DEFAULT_PORT: 1255
    
    _HEOS: {
      PLAY: {
        STREAM:         'browse/play_stream'
      },
      EVENT: {
        PROGRESS:       'player_now_playing_progress'
      }
      GET: {
        CURRENT_TRACK:  'player/get_now_playing_media',
        PLAYERS:        'player/get_players',
        VOLUME:         'player/get_volume'
      },
      QUEUE: {
        REMOVE_ITEM:    'player/remove_from_queue'
      },
      SET: {
        VOLUME:         'player/set_volume'
      },
      
      ENABLE: {
        EVENTS:         'system/register_for_change_events',
        PRETTY_JSON:    'system/prettify_json_response'
      }
    }
    
    constructor: (@config, lastState, options, @debug = false) ->
      @id = @config.id
      @name = @config.name
      @debug = lastState?.debug?.value ? @debug
      
      @_mediaServer = options.mediaServer
      @_listener = options.listener
      
      super(lastState)
      
      @_heosSocket = null
      @_eventSocket = null
      @_volume = {
        current: 0,
        previous: 0
      }
      
    updateDevice: (config) =>
      @_heosEventReceiver(config.address, @_DEFAULT_PORT)
      @_heosConnect(config.address, @_DEFAULT_PORT)
      
      super(config)
      
    playAudio: (@_resource, duration, volume = 40) =>
      @_volume.current = volume
      return @_heosSendCommand(                                 @_HEOS.GET.VOLUME,          { pid: @_pid })
      .then( (response) =>
      
        @_volume.previous = response.payload.level
        @_heosSendCommand(                                      @_HEOS.SET.VOLUME,          { pid: @_pid, level: @_volume.current })
      )
      .then( () => @_heosSendCommand(                           @_HEOS.PLAY.STREAM,         { pid: @_pid }, { url: @_mediaServer.addResource(@_resource) }) )
      .then( () => @_heosSendCommand(                           @_HEOS.GET.CURRENT_TRACK,   { pid: @_pid }) )
      
      .then( (response) =>
        
        return new Promise( (resolve, reject) =>
          onProgress = (info) =>
            if (info.duration - info.cur_pos) < 1000
              @removeListener(@_HEOS.EVENT.PROGRESS, onProgress)
              resolve response.payload.qid
          @on(                                                  @_HEOS.EVENT.PROGRESS, onProgress)
        )
      )
      .then( (qid) => @_heosSendCommand(                        @_HEOS.QUEUE.REMOVE_ITEM,  { pid: @_pid, qid: qid } ) )
      .then( () => @_heosSendCommand(                           @_HEOS.SET.VOLUME,         { pid: @_pid, level: @_volume.previous }) )
      .then( (result) =>
        return Promise.resolve true
      )
      .catch( (error) => @base.rejectWithErrorString( Promise.reject, @_errorHandler(error) ) )
    
    _heosEventReceiver: (host, port) =>
      return new Promise( (resolve, reject) =>
        if !@_eventSocket?
          @_eventSocket = new net.Socket()
            .once( 'connect', () =>
              @_debug('Connected to HEOS device for event messages')
              @_heosSendCommand(                                @_HEOS.ENABLE.EVENTS,       { enable: 'on' }, null, @_eventSocket )
              .then(() => resolve @_eventSocket)
            )
            .on('data', @_heosEventHandler)
            .connect(port, host)
        else
          resolve @_eventSocket
      )
      .catch( (error) => Promise.reject error )
    
    _heosConnect: (host, port, options = {}) =>
      return new Promise( (resolve, reject) =>
        
        if !@_heosSocket?
          @_heosSocket = new net.Socket(options)
            .once( 'error',   (error) =>
              @_heosSocket.destroy()
              @_heosSocket = null
              reject error
            
            )
            .once( 'timeout', () =>
              @_heosSocket.destroy()
              @_heosSocket = null
              reject new Error('timeout')
            
            )
            .once( 'connect', () =>
              
              @_debug('Connected to HEOS device for commands')
              @_heosSendCommand(                  @_HEOS.ENABLE.PRETTY_JSON,  { enable: 'on' })
              .then( () => @_heosSendCommand(     @_HEOS.GET.PLAYERS) )
              .then( (data) =>
                pid = 0
                
                data.payload.map( (player) =>
                  id = __('heos-%s', player.name.toLowerCase().replace(' ', '-'))
                  pid = player.pid if id is @id
                )
                @_pid = pid
              )
              .then( () => resolve @_heosSocket )
            )
            .connect(port, host)
        else
          resolve @_heosSocket
      )
      .catch( (error) =>
        Promise.reject error
      )
    
    _heosSendCommand: (command, attributes = {}, literals = {}, socket = @_heosSocket) =>
      return new Promise( (resolve, reject) =>
        command = URL.format({
          protocol: 'heos',
          slashes:  true,
          pathname: command
          search:   querystring.stringify(attributes)
        })
        command += __('&%s=%s', key, value) for key, value of literals
        
        socket.once( 'data', (buffer) =>
          res = @_heosParseBuffer(buffer)
          response = res[0]
          
          console.log('DATA:')
          @_debug(response)
          console.log('END DATA')
          
          if response.heos.result is 'success'
            resolve response
          
          else if response.heos.result is 'fail'
            reject new Error( _('Error: command "%s" failed with error %s', command, response.heos.message) )
        )
        
        socket.write( command + '\r\n')
      )
      .catch( (error) =>
        Promise.reject error
      )
    
    _heosEventHandler: (buffer) =>
      events = @_heosParseBuffer(buffer)
      events.map( (response) =>
        
        if response.group is 'event'
          #console.log(__('EVENT RECEIVED FROM: %s', @_host))
          #@_debug(response)
          #console.log('END EVENT')
          @emit(response.command, response.payload)
        
      )
    
    _heosParseBuffer: (buffer) =>
      responses = []
      
      messages = buffer.toString().trim().split('\r\n')
      messages.map( ( data) =>
        unless data is ''
          response = JSON.parse( data + '\r\n' )
          if response.heos?.message?
            message = @_heosParseMessage(response.heos.message)
            command = response.heos.command.split('/')
            
            response.heos.message = message
            response.group = command[0]
            response.command = command[1]
            
            if not response.payload? # DATA does not have payload, we add one from message element
              response.payload = message
            
            responses.push response
      )
      return responses
    
    _heosParseMessage: (message) =>
      attributes = {}
      params = message.split('&')
      params.map( (param) =>
        keyValue = param.split('=')
        attributes[keyValue[0]] = keyValue[1]
      )
      return attributes
    
    destroy: =>
      @_heosSocket.destroy() if @_heosSocket?
      @_eventSocket.destroy() if @_eventSocket?
      
      @_debug(__('Disconnected HEOS command and event sockets for: %s', @id))
      
      super()
  
  return HeosMediaPlayerDevice