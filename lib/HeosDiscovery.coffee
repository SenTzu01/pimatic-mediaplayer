module.exports = (env) ->
  
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  MediaPlayerDiscovery = require('./MediaPlayerDiscovery')(env)
  
  class HeosDiscovery extends MediaPlayerDiscovery
    
    constructor: (@_browseInterval, @_browseDuration, @address, @port = 0, @debug = false) ->
      @name = 'HeosDiscovery'
      
      @_schema = 'urn:schemas-denon-com:device:ACT-Denon:1'
      @_type = 'heos'
      
      super()
      
    destroy: () ->
      super()
      
    _getXml: (headers, xml) => return headers['LOCATION'] if headers.ST is @_schema
  
  return HeosDiscovery