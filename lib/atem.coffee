dgram        =  require 'dgram'
EventEmitter = (require 'events').EventEmitter

class ATEM
  DEBUG = if process.env['ATEM_DEBUG'] then process.env['ATEM_DEBUG'] == 'true' else false
  DEFAULT_PORT = 9910
  RECONNECT_INTERVAL = 5000

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

  AUDIO_GAIN_RATE = 65381

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

  @PacketFlag =
    Sync:    0x01
    Connect: 0x02
    Repeat:  0x04
    Unknown: 0x08
    Ack:     0x10

  state:
    tallys: []
    channels: {}
    video:
      upstreamKeyNextState: []
      upstreamKeyState: []
      downstreamKeyOn: []
      downstreamKeyTie: []
      auxs: {}
    audio:
      channels: {}

  connected: false
  localPackedId: 1
  sessionId: []

  constructor: ->
    @event = new EventEmitter
    @event.on 'ping', (err) =>
      @lastConnectAt = new Date().getTime()

    setInterval( =>
      return if @lastConnectAt + RECONNECT_INTERVAL > new Date().getTime()
      if @connected
        @connected = false
        @event.emit 'disconnect', null, null
      @localPackedId = 1
      @sessionId = []
      @connect(@address, @port)
    , RECONNECT_INTERVAL)

  connect: (@address, @port = DEFAULT_PORT, local_port = 0) ->
    local_port ||= 1024 + Math.floor(Math.random() * 64511) # 1024-65535

    @socket = dgram.createSocket 'udp4'
    @socket.on 'message', @_receivePacket
    @socket.bind local_port

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
    return if length != remote.size
    flags = message[0] >> 3
    @sessionId = [message[2], message[3]]

    if flags & ATEM.PacketFlag.Connect
      @_sendPacket COMMAND_CONNECT_HELLO_ANSWER
      unless @connected
        @connected = true
        @event.emit 'connect', null, null
    else if flags & ATEM.PacketFlag.Sync
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

      when 'DskS'
        @state.video.downstreamKeyOn[buffer[0]] = if buffer[1] == 1 then true else false

      when 'DskP'
        @state.video.downstreamKeyTie[buffer[0]] = if buffer[1] == 1 then true else false

      when 'KeOn'
        @state.video.upstreamKeyState[buffer[1]] = if buffer[2] == 1 then true else false

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
          gain: @_parseNumber(buffer[10..11])/AUDIO_GAIN_RATE
          rawGain: @_parseNumber(buffer[10..11])
          # 0xD8F0 - 0x0000 - 0x2710
          rawPan: @_parseNumber(buffer[12..13])
          # 6922

      #AMMO(16)  <Buffer 00 10 00 00 41 4d 4d 4f 80 00 00 00 01 01 00 02>
      #AMMO(16)  <Buffer 00 10 00 00 41 4d 4d 4f 80 00 00 00 00 01 00 02>
      when 'AMMO' # Audio Monitor Master Output
        @state.audio.master =
          afv: if buffer[4] == 1 then true else false
          gain: @_parseNumber(buffer[0..1])/AUDIO_GAIN_RATE
          rawGain: @_parseNumber(buffer[0..1])

      when 'AMLv' # Audio Monitor Level
        numberOfChannels = @_parseNumber(buffer[0..1])
        channelMappings = []
        offset = 4

        # Master volume
        for i in [0..1]
          leftGain = @_parseNumber(buffer[offset+1..offset+3])
          rightGain = @_parseNumber(buffer[offset+5..offset+7])
          @_merge(@state.audio.master, { leftLevel: leftGain/8388607, rightLevel: rightGain/8388607 })
          offset += 16

        # Channel mapping
        for i in [0...numberOfChannels]
          channelMappings.push(buffer[offset] << 8 | buffer[offset + 1])
          offset += 2

        # Channels volume
        for i in [0...numberOfChannels]
          leftGain = @_parseNumber(buffer[offset+1..offset+3])
          rightGain = @_parseNumber(buffer[offset+5..offset+7])
          @_merge(@state.audio.channels[channelMappings[i]], { leftLevel: leftGain/8388607, rightLevel: rightGain/8388607 })
          offset += 16

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

  _numberToBytes: (number, numberOfBytes) ->
    bytes = []
    for i in [0...numberOfBytes]
      shift = numberOfBytes - i - 1
      bytes.push((number >> (8 * shift)) & 0xFF)
    bytes

  _stringToBytes: (str) ->
    bytes = []
    for i in [0...str.length]
      bytes.push(str.charCodeAt(i))
    bytes

  _merge: (obj1, obj2) ->
    obj2 = {} unless obj2?
    for key2 of obj2
      obj1[key2] = obj2[key2] if obj2.hasOwnProperty(key2)

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

  changeDownstreamKeyOn: (number, state) ->
    @_sendCommand('CDsL', [number, state, 0xff, 0xff])

  changeDownstreamKeyTie: (number, state) ->
    @_sendCommand('CDsT', [number, state, 0xff, 0xff])

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

  changeAudioMasterGain: (gain) ->
    gain = gain * AUDIO_GAIN_RATE
    @_sendCommand('CAMM', [0x01, 0x00, gain/256, gain%256, 0x00, 0x00, 0x00, 0x00])

  changeAudioChannelGain: (channel, gain) ->
    gain = gain * AUDIO_GAIN_RATE
    @_sendCommand('CAMI', [0x02, 0x00, channel/256, channel%256, 0x00, 0x00, gain/256, gain%256, 0x00, 0x00, 0x00, 0x00])

  # CAMI command structure:    CAMI    [01=buttons, 02=vol, 04=pan (toggle bits)] - [input number, 0-…] - [buttons] - [buttons] - [vol] - [vol] - [pan] - [pan]
  changeAudioChannelState: (channel, status) ->
    @_sendCommand('CAMI', [0x01, 0x00, channel >> 8, channel & 0xFF, status, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])

  sendAudioLevelNumber: (enable = true) ->
    @_sendCommand('SALN', [enable, 0x00, 0x00, 0x00])

  startRecordMacro: (number, name, description) -> # ATEM response with "MRcS"
    nameLength = name?.length || 0
    descriptionLength = description?.length || 0
    bytes = [0x00, number]
    bytes = bytes.concat(@_numberToBytes(nameLength, 2))
    bytes = bytes.concat(@_numberToBytes(descriptionLength, 2))
    bytes = bytes.concat(@_stringToBytes(name)) if nameLength > 0
    bytes = bytes.concat(@_stringToBytes(description)) if descriptionLength > 0

    @_sendCommand('MSRc', bytes)

  stopRecordMacro: -> # ATEM response with "MRcS"
    @_sendCommand('MAct', [0xFF, 0xFF, 0x02, 0x81]) # Filling number field with 0xFF means special action

  runMacro: (number) -> # ATEM response with "MRPr"
    @_sendCommand('MAct', [0x00, number, 0x00, 0x7d])

  deleteMacro: (number) -> # ATEM response with "MPrp"
    @_sendCommand('MAct', [0x00, number, 0x05, 0x00])

module.exports = ATEM
