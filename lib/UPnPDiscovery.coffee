module.exports = (env) ->
  
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  MediaPlayerDiscovery = require('./MediaPlayerDiscovery')(env)
  
  class UPnPDiscovery extends MediaPlayerDiscovery
    
    constructor: (@_browseInterval, @_browseDuration, @address, @port = 0, @debug = false) ->
      @name = 'UPnPDiscovery'
      
      @_schema = 'urn:schemas-upnp-org:device:MediaRenderer:1'
      @_type = 'generic'
      
      super()
      
    destroy: () ->
      super()
      
    _getXml: (headers, xml) => return headers['LOCATION'] if headers.ST is @_schema
  
  return UPnPDiscovery