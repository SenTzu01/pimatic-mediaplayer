# #pimatic-mediaplayer plugin config options
module.exports = {
  title: "pimatic-mediaplayer plugin config options"
  type: "object"
  properties:
    debug:
      description: "Debug mode. Writes debug messages to the pimatic log, if set to true."
      type: "boolean"
      default: false
    enableDiscovery:
      description: "Enable automatic discovery and adding of DLNA and Chromecast mediaplayers"
      type: "boolean"
      default: false
    discoveryTimeout:
      description: "How long should the DLNA discoverer listen for announcements, in seconds"
      type: "number"
      default: 10
    discoveryInterval:
      description: "How often should the DLNA discoverer refresh, in seconds. Must be at least twice Timeout setting."
      type: "number"
      default: 60
    address:
      description: "Local IP used for streaming media resources to network audio devices. Must be set when multiple interfaces are connected."
      type: "string"
      default: ""
      
}