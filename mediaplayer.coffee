module.exports = (env) ->

  _ = env.require 'lodash'
  Promise = env.require 'bluebird'
  commons = require('pimatic-plugin-commons')(env)
  os = require('os')
  MediaServer = require('./lib/MediaServer')(env)
  
  MediaPlayerProviders =
    generic:
      type: 'UPnP'
      device: 'UPnPMediaPlayerDevice'
      deviceDef: 'mediaplayer-device-config-schemas'
    chromecast:
      type: 'Chromecast'
      device: 'ChromecastMediaPlayerDevice'
      deviceDef: 'mediaplayer-device-config-schemas'
  
  class MediaPlayer extends env.plugins.Plugin
    
    init: (app, @framework, @config) =>
      @debug = @config.debug || false
      @base = commons.base @, 'Plugin'
      
      @_inetAddresses = []
      address = @_configureMediaServerAddress()
      @base.debug address
      @_mediaServer = new MediaServer({ port:0, address: address }, @debug)
      @_mediaServer.create()
      
      listeners = []
      discoveryInterval = @_toMilliSeconds( @config.discoveryInterval ? 30 )
      discoveryDuration = @_toMilliSeconds( @config.discoveryTimeout ? 10 )
      discoveryInterval = discoveryDuration*2 unless discoveryInterval > discoveryDuration*2
      
      for own obj of MediaPlayerProviders
        do (obj) =>
          OutputProvider = MediaPlayerProviders[obj]
          listener = null
          
          unless obj is 'local'
            @base.debug "Starting discovery of #{OutputProvider.type} media player devices"
            Discovery = require("./lib/" + OutputProvider.type + "Discovery")(env)
            listener = new Discovery(discoveryInterval, discoveryDuration, @config.address, null, @debug) #@debug
            listeners.push listener
            
            listener.on('deviceDiscovered', (cfg) =>
              if @config.enableDiscovery and @_isNewDevice(cfg.id)
                newDevice = @_createPimaticDevice(cfg)
                newDevice.updateDevice(cfg)
            )
            listener.start()
          
          className = "#{OutputProvider.device}"
          @base.debug __("Registering device class: %s", className)
          
          deviceConfig = require("./" + OutputProvider.deviceDef)
          deviceClass = require('./devices/' + className)(env)
          
          options = {
            listener: listener,
            mediaServer: @_mediaServer
          }
          
          params = {
            configDef: deviceConfig[className], 
            createCallback: (config, lastState) => return new deviceClass(config, lastState, options, @debug) #@debug
          }
          @framework.deviceManager.registerDeviceClass(className, params)
          
          
      
      #@base.debug "Registering action provider"
      #actionProviderClass = require('./actions/MediaPlayerActionProvider')(env)
      #@framework.ruleManager.addActionProvider(new actionProviderClass(@framework, @config))
    
    _createPimaticDevice: (cfg) =>
      return if !cfg? or !cfg.id? or !cfg.name?
      @base.debug __("Creating new network media player device: %s with IP: %s", cfg.name, cfg.address)
      
      return @framework.deviceManager.addDeviceByConfig({
        id: cfg.id,
        name: cfg.name
        class: MediaPlayerProviders[cfg.type].device
      })
    
    _startMediaServer: (resource) =>
      
      @_mediaServer.create(resource)
    
    _stopMediaServer: () =>
      @_mediaServer.stop() if @_mediaServer?
    
    _isNewDevice: (id) -> 
      return !@framework.deviceManager.isDeviceInConfig(id)
    
    _configureMediaServerAddress: () ->
      @_inetAddresses = @_getConfiguredAddresses()
      
      pluginConfigSchema = @framework.pluginManager.getPluginConfigSchema("pimatic-mediaplayer")
      pluginConfigSchema.properties.address.enum = []
      
      @base.info "Configured external IP addresses:"
      @_inetAddresses.map( (address) =>
        pluginConfigSchema.properties.address.enum.push address.IPv4 if address.IPv4?
        pluginConfigSchema.properties.address.enum.push address.IPv6 if address.IPv6?
        @base.info __("IPv4: %s, IPv6: %s", address.IPv4, address.IPv6)
      )
      
      if @config.address is ""
        serverAddress = @_getPimaticAddress() ? @_inetAddresses[0].IPv4 ? @_inetAddresses[0].IPv6 ? ""
        @config.address = serverAddress
        @framework.pluginManager.updatePluginConfig(@config.plugin, @config)
      
      @base.info __("Address: %s has been configured", @config.address)
      return @config.address
    
    _getConfiguredAddresses: () ->
      netInterfaces = []
      ifaces = os.networkInterfaces()
      for iface, ipConfig of ifaces
        addresses = null
        ipConfig.map( (ip) =>
          if !ip.internal
            addresses ?= { IPv4: "", IPv6: "" }
            addresses[ip.family] = ip.address if ip.family is 'IPv4' or 'IPv6'
        )
        netInterfaces.push addresses if addresses?
      return netInterfaces
    
    _toMilliSeconds: (s) -> return s * 1000
    
    _getPimaticAddress: () ->
      appSettings = @framework.config?.settings
      ip = settings?.httpServer?.hostname ? settings?.httpsServer?.hostname ? null
      env.logger.debug __("User defined IP address in Pimatic settings: %s", ip)
      
      return ip
      
    destroy: () ->
      super()
      
  MediaPlayerPlugin = new MediaPlayer
  return MediaPlayerPlugin