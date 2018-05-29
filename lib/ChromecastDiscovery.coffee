module.exports = (env) ->
  
  Promise = env.require 'bluebird'
  _ = env.require 'lodash'
  commons = require('pimatic-plugin-commons')(env)
  MediaPlayerDiscovery = require('./MediaPlayerDiscovery')(env)
  
  class ChromecastDiscovery extends MediaPlayerDiscovery
    
    constructor: (@_browseInterval, @_browseDuration, @address, @port = 0, @debug = false) ->
      @name = 'ChromecastDiscovery'
      
      @_schema = 'urn:dial-multiscreen-org:service:dial:1'
      @_type = 'chromecast'
      
      super()
      
    destroy: () ->
      super()
    
    _getXml: (headers, xml) => return xml if xml.search('<manufacturer>Google Inc.</manufacturer>') > -1
  
  return ChromecastDiscovery