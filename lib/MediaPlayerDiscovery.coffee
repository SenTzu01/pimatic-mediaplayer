module.exports = (env) ->
  
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  events = require('events')
  commons = require('pimatic-plugin-commons')(env)
  http = require('http')
  SSDP = require('./SSDP')(env)
  util = require('util')
  
  class MediaPlayerDiscovery extends events.EventEmitter
    
    _getXml: () -> throw new Error( __("function _getXml not implemented.") )
    
    constructor: () ->
      @base = commons.base @, @name
      @base.error __("Instance creation failed. _browseInterval and _browseDuration parameters must be passed to the constructor") if !@_browseInterval? or !@_browseDuration?
      
      @_listener = null
      
      @_initDelay = 60*1000
      @_timerStartBrowser = null
      @_timerStopBrowser = null
    
    destroy: () ->
      @stop()
    
    start: () =>
      @_timerStartBrowser = setTimeout(@_startBrowser, @_initDelay)
      
    stop: () =>
      @base.debug _("Stopping SSDP discovery due to external instruction")
      clearTimeout @_timerStartBrowser if @_timerStartBrowser?
      clearTimeout @_timerStopBrowser if @_timerStopBrowser?
      @_stopBrowser()
    
    _stopBrowser: () =>
      @_listener.destroy()
      @_listener = null
      
      @base.debug __("Media player discovery stopped\n")
      @emit('discoveryStopped', true)
    
    _startBrowser: () =>
      @_debug( __("Media player discovery started") )
      
      @_listener = new SSDP(@address, @port, @_debug)
      
      @_listener.on('ssdpResponse', @_onSsdpResponse)
      @_listener.search( @_schema )
      
      @emit('discoveryStarted', true)
      
      @_timerStopBrowser = setTimeout(@_stopBrowser, @_browseDuration)
      @_timerStartBrowser = setTimeout(@_startBrowser, @_browseInterval)
      
      return
    
    _onSsdpResponse: (headers, rinfo) =>
      if headers['LOCATION'] and headers['LOCATION'].indexOf('https://') < 0
        
        @_getXmlDoc(headers.LOCATION)
        .then( (xmlDoc) =>
          xml = @_getXml(headers, xmlDoc)
          name = @_getFriendlyName(xmlDoc)
          
          if xml? and name?
            config = {
              id:       @_createDeviceId(name, @_type)
              name:     @_createDeviceName(name)
              type:     @_type
              address:  rinfo.address
              xml:      xml
            }
            #@base.debug ( __("Emitting device announcement for %s - %s", headers.LOCATION, config.id) )
            
            @emit('deviceDiscovered', config)
        )
        
    _getFriendlyName: (xml) =>
      matches = xml.match(/<friendlyName>(.+?)<\/friendlyName>/)
      return matches[1] if matches?
    
    _getXmlDoc: (url) =>
      return new Promise( (resolve, reject) =>
      
        request = http.request(url)
        request.on('response', (res) =>
          body = ''
          
          res.on('data', (chunk) =>
            body += chunk
          )
          
          res.on('end', () =>
            resolve body
          )
          
          res.on('error', (error) =>
            reject error
          )
        )
        request.end()
      )
      .catch( (error) =>
        @base.resetLastError()
        @base.rejectWithErrorString( Promise.reject, error, __("There was an error obtaining the XML document") )
      )
    
    _safeString: (string, char) ->    return string.replace(/(^[\W]|[\W]$)/g, '').replace(/[\W]+/g, char)
    _createDeviceId: (fname, type) -> return __("%s-%s", type, @_safeString( fname, '-').toLowerCase() )
    _createDeviceName: (fname) ->     return __("Media player %s", @_safeString( fname, ' ') )
    
    _debug: (msg) ->
      if @debug
        if typeof msg is 'object'
          util = require('util')
          msg = util.inspect( msg, {showHidden: true, depth: null } )
        env.logger.debug __("[%s] %s", @name, msg)
  
  return MediaPlayerDiscovery