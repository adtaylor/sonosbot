# What tune is this?
#
# sonos - show what's playing on the office Sonos
#
xml2js = require 'xml2js'
util = require 'util'

wrapInEnvelope = (body) ->
    """
    <?xml version="1.0" encoding="utf-8"?>
    <s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
      <s:Body>#{body}</s:Body>
    </s:Envelope>
    """

getURL = (path) ->
    host = process.env.HUBOT_SONOS_HOST
    "http://#{host}:1400#{path}"

makeRequest = (msg, path, action, body, response, cb) ->
    wrappedBody = wrapInEnvelope body

    msg.http(getURL path).header('SOAPAction', action).header('Content-type', 'text/xml; charset=utf8')
        .post(wrappedBody) (err, resp, body) ->
            unless err?
                (new xml2js.Parser()).parseString body, (err, json) ->
                    unless err?
                        body = json['s:Body']
                        if body?
                            response_body = body[response]
                            if response_body?
                                cb response_body

actionRequest = (msg, action, body, passResp, success, path="/MediaRenderer/AVTransport/Control") ->
  msg.http(getURL path).header('SOAPAction', action).header('Content-type', 'text/xml; charset=utf8')
      .post(wrapInEnvelope(body)) (err, resp, body) ->
          unless err?
              if passResp is body then msg.send success


playing = (msg) ->
    body = """
    <u:GetPositionInfo xmlns:u="urn:schemas-upnp-org:service:AVTransport:1">
      <InstanceID>0</InstanceID>
      <Channel>Master</Channel>
    </u:GetPositionInfo>
    """

    action = 'urn:schemas-upnp-org:service:AVTransport:1#GetPositionInfo'
    path = '/MediaRenderer/AVTransport/Control'

    makeRequest msg, path, action, body, 'u:GetPositionInfoResponse', (obj) ->
        metadata = obj.TrackMetaData
        if metadata?
            (new xml2js.Parser()).parseString metadata, (err, obj) ->
                unless err?
                    item = obj?.item
                    if item?
                        title = item['dc:title'] ? "(no title)"
                        artist = item['dc:creator'] ? "(no artist)"
                        album = item['upnp:album'] ? "(no album)"
                        artURI = item['upnp:albumArtURI']
                        if artURI?
                            artURI = getURL artURI + "#.png"

                        reply = "Now playing: \"#{title}\" by #{artist} (off of \"#{album}\") #{artURI}"
                        msg.reply reply




pause = (msg)->
  action = '"urn:schemas-upnp-org:service:AVTransport:1#Pause"'
  body = '<u:Pause xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID><Speed>1</Speed></u:Pause>'
  passResp = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:PauseResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"></u:PauseResponse></s:Body></s:Envelope>'
  actionRequest msg,action, body, passResp , 'Sonos paused'


play = (msg)->
  action = '"urn:schemas-upnp-org:service:AVTransport:1#Play"'
  body = '<u:Play xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"><InstanceID>0</InstanceID><Speed>1</Speed></u:Play>'
  passResp = '<s:Envelope xmlns:s="http://schemas.xmlsoap.org/soap/envelope/" s:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/"><s:Body><u:PlayResponse xmlns:u="urn:schemas-upnp-org:service:AVTransport:1"></u:PlayResponse></s:Body></s:Envelope>'
  actionRequest msg, action, body, passResp , 'Sonos playing'



module.exports = (robot) ->
  console?.log 'Hi'
  robot.respond /sonos (.*)/i, (msg) ->
    switch msg.match[1]
      when "pause" then pause msg
      when "play" then play msg
      when "?" then playing msg
      else msg.send 'nah, do it yourself'