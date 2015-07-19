dgram        =  require 'dgram'
EventEmitter = (require 'events').EventEmitter

class ATEM
  DEBUG = if process.env['ATEM_DEBUG'] then process.env['ATEM_DEBUG'] == 'true' else false
  DEFAULT_PORT = 9910

  COMMAND_CONNECT_HELLO = [
    0x10, 0x14, 0x53, 0xAB,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x3A, 0x00, 0x00,
    0x01, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00
  ]

  COMMAND_CONNECT_HELLO_ANSWER = [
    0x80, 0x0C, 0x53, 0xAB,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x03, 0x00, 0x00
  ]

  @Model =
    'TVS':     0x01
    '1ME':     0x02
    '2ME':     0x03
    'PS4K':    0x04
    '1ME4K':   0x05
    '2ME4K':   0x06
    '2MEBS4K': 0x07

  @TransitionStyle =
    MIX:   0x00
    DIP:   0x01
    WIPE:  0x02
    DVE:   0x03
    STING: 0x04

  @TallyState =
    None:    0x00
    Program: 0x01
    Preview: 0x02

  constructor: (local_port = 0) ->
    local_port ||= 1024 + Math.floor(Math.random() * 64511) # 1024-65535

    @state = {
      tallys : []
      channels: {}
      video: { upstreamKeyNextState: [], upstreamKeyState: [], auxs: {} }
      audio: { channels: {} }
    }
    @localPackedId = 1

    @socket = dgram.createSocket 'udp4'
    @socket.on 'message', @_receivePacket
    @socket.bind local_port
    @sessionId = []
    @event = new EventEmitter

  connect: (@address, @port = DEFAULT_PORT) ->
    @_sendPacket COMMAND_CONNECT_HELLO

  on: (name, callback) ->
    @event.on name, callback

  once: (name, callback) ->
    @event.once name, callback

  _sendCommand: (command, options) ->
    message = []
    message[0] = (20+options.length)/256 | 0x08
    message[1] = (20+options.length)%256
    message[2] = @sessionId[0]
    message[3] = @sessionId[1]
    message[10] = @localPackedId/256
    message[11] = @localPackedId%256
    message[12] = (8+options.length)/256
    message[13] = (8+options.length)%256
    message[16] = command.charCodeAt 0
    message[17] = command.charCodeAt 1
    message[18] = command.charCodeAt 2
    message[19] = command.charCodeAt 3
    for byte, i in options
      message[20+i] = byte
    @_sendPacket message
    @localPackedId++

  _sendPacket: (message) ->
    buffer = new Buffer message

    console.log 'SEND', buffer if DEBUG

    @socket.send buffer, 0, buffer.length, @port, @address

  _receivePacket: (message, remote) =>
    length = ((message[0] & 0x07) << 8) | message[1]
    flags = message[0] >> 3
    return if length != remote.size

    @sessionId = [message[2], message[3]]
    # if flags != 0x00
      # console.log "non zero flag", flags, message
    # @remotePacketId = message[10] << 8 | message[11]
    if remote.size == 20 # Bad
      @_sendPacket COMMAND_CONNECT_HELLO_ANSWER
      @event.emit 'connect', null, null
    else if flags & 0x01 || flags & 0x02
      @_sendPacket [
        0x80, 0x0C, @sessionId[0], @sessionId[1],
        message[10], message[11], 0x00, 0x00,
        0x00, 0x41, 0x00, 0x00
      ]
      @event.emit 'ping', null, null
    if remote.size > 12 && remote.size != 20
      @_parseCommand message.slice(12)
      @event.emit 'stateChanged', null, @state

  _parseCommand: (buffer) ->
    length = @_parseNumber(buffer[0..1])
    name = @_parseString(buffer[4..7])

    console.log 'RECV', "#{name}(#{length})", buffer.slice(0, length) if DEBUG

    @_setStatus name, buffer.slice(0, length).slice(8)
    if buffer.length > length
      @_parseCommand buffer.slice(length)

  _setStatus: (name, buffer) ->
    switch name
      when '_ver'
        @state._ver0 = buffer[1]
        @state._ver1 = buffer[3]

      when '_pin'
        @state._pin = @_parseString(buffer)
        @state.model = buffer[40] # XXX: is this sure?

      when 'InPr'
        channel = @_parseNumber(buffer[0..1])
        @state.channels[channel] =
          name: @_parseString(buffer[2..21])
          label: @_parseString(buffer[22..25])

      when 'PrgI'
        @state.video.programInput = @_parseNumber(buffer[2..3])

      when 'PrvI'
        @state.video.previewInput = @_parseNumber(buffer[2..3])

      when 'TrPr'
        @state.video.transitionPreview = if buffer[1] > 0 then true else false

      when 'TrPs'
        @state.video.transitionPosition = @_parseNumber(buffer[4..5])/10000 # 0 - 10000
        @state.video.transitionFrameCount = buffer[2] # 0 - 30

      when 'TrSS'
        @state.video.transitionStyle = @_parseNumber(buffer[0..1])
        @state.video.upstreamKeyNextBackground = (buffer[2] >> 0 & 1) == 0x01
        @state.video.upstreamKeyNextState[0] = (buffer[2] >> 1 & 1) == 0x01
        if @state.model != ATEM.Model.TVS && @state.model != ATEM.Model.PS4K
          @state.video.upstreamKeyNextState[1] = (buffer[2] >> 2 & 1) == 0x01
          @state.video.upstreamKeyNextState[2] = (buffer[2] >> 3 & 1) == 0x01
          @state.video.upstreamKeyNextState[3] = (buffer[2] >> 4 & 1) == 0x01

      when 'KeOn'
        @state.video.upstreamKeyState[buffer[1]] = buffer[2] == 1 ? true : false

      when 'FtbS' # Fade To Black Setting
        @state.video.fadeToBlack = if buffer[1] > 0 then true else false

      when 'TlIn' # Tally Input
        @state.tallys = @_bufferToArray(buffer[2..])

      when 'AuxS' # Auxially Setting
        aux = buffer[0]
        @state.video.auxs[aux] = @_parseNumber(buffer[2..3])

      when 'AMIP' # Audio Monitor Input Position
        channel = @_parseNumber buffer[0..1]
        @state.audio.channels[channel] =
          on: if buffer[8] == 1 then true else false
          afv: if buffer[8] == 2 then true else false
          gain: @_parseNumber(buffer[10..11])/65381
          rawGain: @_parseNumber(buffer[10..11])
          # 0xD8F0 - 0x0000 - 0x2710
          rawPan: @_parseNumber(buffer[12..13])
          # 6922

      #AMMO(16)  <Buffer 00 10 00 00 41 4d 4d 4f 80 00 00 00 01 01 00 02>
      #AMMO(16)  <Buffer 00 10 00 00 41 4d 4d 4f 80 00 00 00 00 01 00 02>
      # Audio Monitor Level
      # <Buffer 00 03 f2 73 00 03 dc 98 00 7f db a2 00 7f e0 cb> = Master
      # <Buffer 00 00 03 33 00 20 00 00 43 43 64 50 03 08 00 80> = Info???
      # <Buffer 00 01 00 02 00 03 00 04 00 05 00 06 04 4d 00 00> = Info?
      # <Buffer 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00> 0 0 0
      # <Buffer 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00> 1 0 0
      # <Buffer 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00> 2 0 0
      # <Buffer 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00> 3 0 0
      # <Buffer 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00> 4 0 0
      # <Buffer 00 03 f2 73 00 03 dc 98 00 7f db a2 00 7f e0 cb> 5 0.03083646665054162 258675
      # <Buffer 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00> 6 0 0 = EXT ?
      # channel info examples
      #        0x07D1 = 2001 = MP1
      #        0x07D2 = 2002 = MP2
      #        0x03E9 = 1001 = EXT
      #        0x04b1 = 1201 = RCA
      # ATEM TVS
      # 172 = | 4byte | Command code (AMLv) 4byte |
      #       | 2byte channel num | 2byte channel num| master | zero | channels...
      when 'AMLv'
        channel = buffer[0]*256 + buffer[1]
        offset = 4
        channels = []

        # Master volume
        for i in [0...3]
          if i == 0
            gain = buffer[offset + 1] << 16 |
                   buffer[offset + 2] << 8 |
                   buffer[offset + 3]
            @state.audio.master = { gain: gain/8388607, raw: gain }
          else if i == 2
            for j in [0...8]
              number = buffer[offset + j*2] << 8 | buffer[offset + j*2 + 1]
              channels.push number if number != 0
          offset = offset + 16

        # Channels volume
        for i in [0...numberOfChannels]
          gain = buffer[offset + 1] << 16 |
                 buffer[offset + 2] << 8 |
                 buffer[offset + 3]
          @state.audio[channels[i]] = { gain: gain/8388607, raw: gain }
          offset = offset + 16

  # Convert number from bytes.
  _parseNumber: (bytes) ->
    num = 0
    for byte, i in bytes
      num += byte
      num = num << 8 if (i < bytes.length-1)
    num

  # Convert string from character array.
  # If appear null character in array, ignore thereafter chars.
  _parseString: (bytes) ->
    str = ''
    for char in bytes
      break if char == 0
      str += String.fromCharCode(char)
    str

  _bufferToArray: (buffers) ->
    arr = []
    for buffer in buffers
      arr.push(buffer)
    arr

  sendAudioLevelNumber: ->
    @_sendCommand('SALN', [0x01, 0x00, 0x00, 0x00])

  changeProgramInput: (input) ->
    @_sendCommand('CPgI', [0x00, 0x00, input >> 8, input & 0xFF])

  changePreviewInput: (input) ->
    @_sendCommand('CPvI', [0x00, 0x00, input >> 8, input & 0xFF])

  changeAuxInput: (aux, input) ->
    @_sendCommand('CAuS', [0x01, aux, input >> 8, input & 0xFF])

  fadeToBlack: ->
    @_sendCommand('FtbA', [0x00, 0x02, 0x58, 0x99])

  autoTransition: ->
    @_sendCommand('DAut', [0x00, 0x00, 0x00, 0x00])

  cutTransition: ->
    @_sendCommand('DCut', [0x00, 0xef, 0xbf, 0x5f])

  changeTransitionPosition: (position) ->
    @_sendCommand('CTPs', [0x00, 0xe4, position/256, position%256])
    @_sendCommand('CTPs', [0x00, 0xf6, 0x00, 0x00]) if position == 10000

  changeTransitionPreview: (state) ->
    @_sendCommand('CTPr', [0x00, state, 0x00, 0x00])

  changeTransitionType: (type) ->
    @_sendCommand('CTTp', [0x01, 0x00, type, 0x02])

  changeUpstreamKeyState: (number, state) ->
    @_sendCommand('CKOn', [0x00, number, state, 0x90])

  changeUpstreamKeyNextBackground: (state) ->
    @state.video.upstreamKeyNextBackground = state
    states = @state.video.upstreamKeyNextBackground +
      (@state.video.upstreamKeyNextState[0] << 1) +
      (@state.video.upstreamKeyNextState[1] << 2) +
      (@state.video.upstreamKeyNextState[2] << 3) +
      (@state.video.upstreamKeyNextState[3] << 4)
    @_sendCommand('CTTp', [0x02, 0x00, 0x6a, states])

  changeUpstreamKeyNextState: (number, state) ->
    @state.video.upstreamKeyNextState[number] = state
    states = @state.video.upstreamKeyNextBackground +
      (@state.video.upstreamKeyNextState[0] << 1) +
      (@state.video.upstreamKeyNextState[1] << 2) +
      (@state.video.upstreamKeyNextState[2] << 3) +
      (@state.video.upstreamKeyNextState[3] << 4)
    @_sendCommand('CTTp', [0x02, 0x00, 0x6a, states])

  changeAudioChannelGain: (channel, gain) ->
    gain = gain * 65381
    @_sendCommand('CAMI', [0x02, 0x00, channel/256, channel%256, 0x00, 0x00, gain/256, gain%256, 0x00, 0x00, 0x00, 0x00])

  # CAMI command structure:    CAMI    [01=buttons, 02=vol, 04=pan (toggle bits)] - [input number, 0-…] - [buttons] - [buttons] - [vol] - [vol] - [pan] - [pan]
  changeAudioChannelState: (channel, status) ->
    @_sendCommand('CAMI', [0x01, 0x00, channel >> 8, channel & 0xFF, status, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])

module.exports = ATEM
