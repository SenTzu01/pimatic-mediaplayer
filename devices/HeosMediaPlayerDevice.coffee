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
      
      @_eventSocket = new net.Socket()
        .once( 'connect', () =>
          console.log(__('Connected to HEOS for events: %s:%s', @_host, @_DEFAULT_PORT))
          @_heosSendCommand(              @_HEOS.ENABLE.EVENTS,       { enable: 'on' }, null, @_eventSocket )
        )
        .on('data', @_heosEventHandler)
        .connect(@_DEFAULT_PORT, @_host)
        
      @_heosConnect(@_host, @_DEFAULT_PORT)
      .then( () => @_heosSendCommand(     @_HEOS.ENABLE.PRETTY_JSON,  { enable: 'on' }) if @debug )
      .then( () => @_heosSendCommand(     @_HEOS.GET.PLAYERS) )
      .then( (data) =>
        pid = 0
        
        data.payload.map( (player) =>
          id = __('heos-%s', player.name.toLowerCase().replace(' ', '-'))
          pid = player.pid if id is @id
        )
        @_pid = pid
      )
      
      
    
    playAudio: (@_resource, duration, volume = 40) =>
      @_volume.current = volume
      
      return @_heosSendCommand(           @_HEOS.GET.VOLUME,          { pid: @_pid })
      
      .then( (response) =>
        
        @_volume.previous = response.payload.level
        @_heosSendCommand(                @_HEOS.SET.VOLUME,          { pid: @_pid, level: @_volume.current })
      )
      .then( () => @_heosSendCommand(     @_HEOS.PLAY.STREAM,         { pid: @_pid }, { url: @_mediaServer.addResource(@_resource) }) )
      
      .delay(1000)
      .then( () => @_heosSendCommand(     @_HEOS.GET.CURRENT_TRACK,   { pid: @_pid }) )
      
      .then( (response) =>
        return new Promise( (resolve, reject) =>
          @once(                          @_HEOS.EVENT.PROGRESS, (info) =>
            ms = info.duration - info.cur_pos
            
            resolve Promise.delay(ms, response.payload.qid)
          )
        )
      
      )
      .then( (qid) => @_heosSendCommand(  @_HEOS.QUEUE.REMOVE_ITEM,  { pid: @_pid, qid: qid } ) )
      .then( () => @_heosSendCommand(     @_HEOS.SET.VOLUME,          { pid: @_pid, level: @_volume.previous }) )
      .catch( (error) => @base.rejectWithErrorString( Promise.reject, @_errorHandler(error) ) )
    
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
              console.log(__('Connected to HEOS: %s:%s', @_host, port))
              resolve @_heosSocket
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
        
        socket.once( 'data', (data) =>
          responses = data.toString().trim().split('\r\n')
          
          responses.map( ( response) =>
            res = JSON.parse( response + '\r\n' ) unless response is ''
            
            if res?.heos?.result?
              
              if !res.payload?
                attributes = {}
            
                if res.heos.message?
                  params = res.heos.message.split('&')
                  params.map( (param) =>
                    keyValue = param.split('=')
                    attributes[keyValue[0]] = keyValue[1]
                  )
                res.payload = attributes
              
              console.log('DATA:')
              @_debug(res)
              console.log(__('Data received from: %s', @_host))
              
              resolve res if res.heos.result is 'success'
              reject new Error( _('Error: command "%s" failed with error %s', command, res.heos.message) ) if res.heos.result is 'fail'
          )
        )
        
        socket.write( command + '\r\n')
      )
      .catch( (error) =>
        Promise.reject error
      )
    
    _heosEventHandler: (buffer) =>
      data = buffer.toString().trim().split('\r\n')
      data.map( ( response) =>
        res = JSON.parse( response + '\r\n' ) unless response is ''
        
        if res?.heos?.command?
          groupCommand = res.heos.command.split('/')
          
          if 'event' is groupCommand[0]
            
            console.log(__('EVENT RECEIVED FROM: %s', @_host))
            @_debug(res)
            
            attributes = {}
            
            if res.heos.message?
              params = res.heos.message.split('&')
              params.map( (param) =>
                keyValue = param.split('=')
                attributes[keyValue[0]] = keyValue[1]
              )
              
              console.log('END EVENT')
            
            @emit(groupCommand[1], attributes)
      )
    
    destroy: =>
      @_heosSocket.destroy()
      @_eventSocket.destroy()
      
      console.log(__('Disconnected from HEOS: %s', @_host))
      
      super()
  
  return HeosMediaPlayerDevice