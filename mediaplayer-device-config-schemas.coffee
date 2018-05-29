module.exports = {
  title: "Media player device config schemas"
  UPnPMediaPlayerDevice: {
    title: "UPnP Media player device config options"
    type: "object"
    properties:
      debug:
        description: "Debug this device."
        type: "boolean"
        default: false
        required: false
  }
  ChromecastMediaPlayerDevice: {
    title: "Chromecast Media player device config options"
    type: "object"
    properties:
      debug:
        description: "Debug this device."
        type: "boolean"
        default: false
        required: false
  }
}
