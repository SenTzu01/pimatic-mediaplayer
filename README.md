# pimatic-tts
This plugin provides Text-to-Speech (TTS) functionality to Pimatic

## Features
- Provides a rule action allowing Pimatic to speak text over connected speakers
- Currently supports the cloud based Google TTS API and Pico2Wave on Linux for offline TTS
- Device approach holding the config allows for shorter action definitions, as most config will always be the same. You can configure several devices each holding a different output config. 
- Device approach also allows for greater flexibility from a development perspective
- Plugin has been created to easily plugin other TTS platforms in future, as well as audio output devices
- Audio output to connected audio devices is achieved by streaming PCM audio to the ALSA backend on Debian/Ubuntu

## Rule syntax and examples: 

### Syntax
<b>Say "text with $pimatic-variables" using TTSDevice </b>

* TTSDevice - determines the Text-to-Speech device to use for speech synthesis. 

### Example
- when trigger: $activity is "wakeup" then Say "Goodmorning everyone! I have set the home for waking up comfortably." using google-tts-device


## Installation and Configuration:

### Install prerequisites as needed for your system:
- ALSA
- Alsa.h (Needed for compiling modules on which pimatic-tts depends)
- mpg321
- lame
- Pico2Wave (For using offline Text-To-Speech)

  # sudo apt-get install libttspico0 libttspico-utils libttspico-data alsa-utils

Raspbian / Debian example to install prerequisites:
Google TTS : ````sudo apt-get install alsa-utils mpg123 lame libasound2-dev````
Pico2Wave: ````sudo apt-get install libttspico0 libttspico-utils libttspico-data alsa-utils````

### Installation
- Install Pimatic-tts via the Pimatic frontend (preferred), activate the plugin and restart Pimatic
- Alternatively add it to the Plugin section of your config.json (be sure to stop Pimatic before making modifications!):
````json
{
  "plugin": "tts",
  "active": true
}
````

### Support

## Known issues:
- Google cloud limits the length of a TTS text string to 200 characters (should be sufficient for most use cases)
- Pimatic-tts (Google TTS API) requires an internet connection (which likely is the case already as you want to install the plugin)

## Changelog:
- V0.0.1 - Initial version providing speech synthesis using the Google TTS API

## Roadmap
- Implement an offline voice synthesizer next to the existing Google API
- Implement the ability to deliver speech through network connected devices (We should dream, shouldn't we)
