module.exports = (env) ->

  events = require('events')
  dgram = require('dgram')
  
  class SSDP extends events.EventEmitter
    _MULTICAST_ADDR: '239.255.255.250'
    _SSDP_PORT: 1900
    _SEND_INTERVAL: 5*1000
    _SSDP_HEADER: /^([^:]+):\s*(.*)$/
    
    constructor: (address, port = 0, @debug = false) ->
      
      @_mSearch  = 'M-SEARCH * HTTP/1.1\r\n'
      @_mSearch += __("HOST: %s:%s\r\n", @_MULTICAST_ADDR, @_SSDP_PORT)
      @_mSearch += 'MAN: "ssdp:discover"\r\n'
      @_mSearch += 'ST: $st\r\n'
      @_mSearch += 'MX: 3\r\n\r\n'
      @_processed = []
      @_interval = null
      
      @_socket = dgram.createSocket('udp4')
        .on('message', (message, rinfo) =>
          return if @_processed.indexOf(rinfo.address) != -1 or @_getStatusCode(message.toString()) != 200
          @_debug __("Received response from device: %s", rinfo.address)
          
          @_parseResponse(message, rinfo)
        )
        
        .on('listening', () =>
          @_socket.addMembership(@_MULTICAST_ADDR)
          
          ip = @_socket.address()
          @_debug __("Listening on %s:%s for ssdp announcements", ip.address, ip.port)
        )
        
        .bind(port, address)
    
    destroy: () ->
      @_socket.close()
      @_socket = null
      return if !@_interval
      clearInterval(@_interval)
      
    search: (st) =>
      send = => @_sendDatagram(st)
      
      send()
      @_interval = setInterval( send, @_SEND_INTERVAL )
    
    _sendDatagram: (st) =>
      #@_debug __("Sending UDP datagram")
      
      message = new Buffer( @_mSearch.replace('$st', st), 'ascii' )
      @_socket.send(message, 0, message.length, @_SSDP_PORT, @_MULTICAST_ADDR)
    
    _parseResponse: (message, rinfo) =>
      headers = @_getHeaders( message.toString() )
      @_processed.push(rinfo.address)
      
      @emit('ssdpResponse', headers, rinfo)
    
    _getStatusCode: (res) =>
      lines = res.split('\r\n')
      type = lines.shift().split(' ')
      
      return parseInt(type[1], 10)
    
    _getHeaders: (res) =>
      headers = {}
      
      lines = res.split('\r\n')
      lines.map( (line) =>
        if line.length
          pairs = line.match(@_SSDP_HEADER)
          headers[pairs[1].toUpperCase()] = pairs[2] if pairs
      )
      
      return headers
      
    _debug: (msg) ->
      env.logger.debug __("[SSDP] %s", msg) if @debug
      
    
  return SSDP