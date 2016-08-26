async  = require 'async'
chai   = require 'chai'
expect = chai.expect
(require 'it-each')()

ATEM   = require '../lib/atem'

ATEM_ADDR = process.env['ATEM_ADDR'] || '172.16.0.2'
ATEM_PORT = process.env['ATEM_PORT'] || 9910
TIMEOUT = process.env['TIMEOUT'] || 10000

describe 'Atem', ->
  @timeout TIMEOUT
  sw = new ATEM

  before (done) ->
    sw.once('connect', done)
    sw.connect(ATEM_ADDR, ATEM_PORT)

  getCameraInputs = ->
    Object.keys(sw.state.channels).reduce((arr, input) ->
      arr.push(parseInt(input)) if input < 4000
      arr
    , [])

  describe 'changeProgramInput', ->
    before (done) ->
      sw.changeProgramInput(1)
      setTimeout(done, 100)

    it 'expects change all camera input', (done) ->
      async.eachSeries(getCameraInputs(), (input, next) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.video.ME[0].programInput).be.eq(input)
          next err, null
        )
        sw.changeProgramInput(input)
      , done)

  describe 'changePreviewInput', ->
    before (done) ->
      sw.changePreviewInput(1)
      setTimeout(done, 100)

    it 'expects change all camera input', (done) ->
      async.eachSeries(getCameraInputs(), (input, next) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.video.ME[0].previewInput).be.eq(input)
          next err, null
        )
        sw.changePreviewInput(input)
      , done)

  describe 'changeAuxInput', ->
    before (done) ->
      sw.changeAuxInput(0, 1)
      sw.changeAuxInput(1, 1)
      sw.changeAuxInput(2, 1)
      setTimeout(done, 100)

    it 'expects change all camera input', (done) ->
      auxs =  Object.keys(sw.state.video.auxs)
      async.eachSeries(auxs, (aux, nextAux) ->
        async.eachSeries(getCameraInputs(), (input, next) ->
          sw.once('stateChanged', (err, state) ->
            expect(state.video.auxs[aux]).be.eq(input)
            next err, null
          )
          sw.changeAuxInput(parseInt(aux), input)
        , nextAux)
      , done)

  describe 'fadeToBlack', ->
    before (done) ->
      sw.fadeToBlack() if sw.state.video.ME[0].fadeToBlack
      setTimeout(done, 1500)

    it 'expects fade to black', (done) ->
      setTimeout( ->
        expect(sw.state.video.ME[0].fadeToBlack).be.true
        done null, null
      , 1500)
      sw.fadeToBlack()

    it 'expects restore fade to black', (done) ->
      setTimeout( ->
        expect(sw.state.video.ME[0].fadeToBlack).be.false
        done null, null
      , 1500)
      sw.fadeToBlack()

  describe 'autoTransition', ->
    before (done) ->
      sw.changeTransitionType(ATEM.TransitionStyle.MIX)
      sw.changeProgramInput(1)
      sw.changePreviewInput(2)
      setTimeout(done, 100)

    it 'expects set program and preview input', ->
      expect(sw.state.video.ME[0].programInput).be.eq(1)
      expect(sw.state.video.ME[0].previewInput).be.eq(2)

    it 'expects swap program and preview input', (done) ->
      setTimeout( ->
        expect(sw.state.video.ME[0].programInput).be.eq(2)
        expect(sw.state.video.ME[0].previewInput).be.eq(1)
        done null, null
      , 1500)
      sw.autoTransition()

  describe 'cutTransition', ->
    before (done) ->
      sw.changeProgramInput(1)
      sw.changePreviewInput(2)
      setTimeout(done, 100)

    it 'expects set program and preview input', ->
      expect(sw.state.video.ME[0].programInput).be.eq(1)
      expect(sw.state.video.ME[0].previewInput).be.eq(2)

    it 'expects swap program and preview input', (done) ->
      sw.once('stateChanged', (err, state) ->
        expect(state.video.ME[0].programInput).be.eq(2)
        expect(state.video.ME[0].previewInput).be.eq(1)
        done err, null
      )
      sw.cutTransition()

  describe 'changeTransitionPosition', ->
    initialize = (done) ->
      sw.changeTransitionPosition(0)
      setTimeout(done, 100)

    before initialize

    it 'expects change transition position', (done) ->
      sw.once('stateChanged', (err, state) ->
        expect(state.video.ME[0].transitionPosition).be.eq(0.5)
        done err, null
      )
      sw.changeTransitionPosition(5000)

    after initialize

  describe 'changeTransitionPreview', ->
    initialize = (done) ->
      sw.changeTransitionPreview(false) if sw.state.video.ME[0].transitionPreview
      setTimeout(done, 100)

    before initialize

    it 'expects false', ->
      expect(sw.state.video.ME[0].transitionPreview).be.false

    it 'expects true when enable', (done) ->
      sw.once('stateChanged', (err, state) ->
        expect(state.video.ME[0].transitionPreview).be.true
        done err, null
      )
      sw.changeTransitionPreview(true)

    after initialize

  describe 'changeTransitionType', ->
    before (done) ->
      sw.changeTransitionType(ATEM.TransitionStyle.DIP)
      setTimeout(done, 100)

    it 'expects change all transition type', (done) ->
      types = if sw.state.model == ATEM.Model.TVS || sw.state.model == ATEM.Model.PS4K
        [ATEM.TransitionStyle.MIX, ATEM.TransitionStyle.DIP, ATEM.TransitionStyle.WIPE]
      else
        (v for k, v of ATEM.TransitionStyle)

      async.eachSeries(types, (type, next) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.video.ME[0].transitionStyle).be.eq(type)
          next err, null
        )
        sw.changeTransitionType(type)
      , done)

  describe 'changeDownstreamKeyOn', ->
    initialize = (done) ->
      async.eachOfSeries(sw.state.video.downstreamKeyOn, (state, index, next) ->
        sw.changeDownstreamKeyOn(index, false)
        next null, null
      )
      setTimeout(done, 100)

    before initialize

    it 'expects change', (done) ->
      async.eachOfSeries(sw.state.video.downstreamKeyOn, (state, index, next) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.video.downstreamKeyOn[index]).be.true
          next err, null
        )
        sw.changeDownstreamKeyOn(index, true)
      , done)

    after initialize

  describe 'changeDownstreamKeyTie', ->
    initialize = (done) ->
      async.eachOfSeries(sw.state.video.downstreamKeyTie, (state, index, next) ->
        sw.changeDownstreamKeyTie(index, false)
        next null, null
      )
      setTimeout(done, 100)

    before initialize

    it 'expects change', (done) ->
      async.eachOfSeries(sw.state.video.downstreamKeyTie, (state, index, next) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.video.downstreamKeyTie[index]).be.true
          next err, null
        )
        sw.changeDownstreamKeyTie(index, true)
      , done)

    after initialize

  describe 'changeUpstreamKeyState', ->
    initialize = (done) ->
      async.eachOfSeries(sw.state.video.ME[0].upstreamKeyState, (state, index, next) ->
        sw.changeUpstreamKeyState(index, false)
        next null, null
      )
      setTimeout(done, 100)

    before initialize

    it 'expects change', (done) ->
      async.eachOfSeries(sw.state.video.ME[0].upstreamKeyState, (state, index, next) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.video.ME[0].upstreamKeyState[index]).be.true
          next err, null
        )
        sw.changeUpstreamKeyState(index, true)
      , done)

    after initialize

  describe 'changeUpstreamKeyNextBackground', ->
    initialize = (done) ->
      sw.changeUpstreamKeyNextState(0, false)
      sw.changeUpstreamKeyNextBackground(true)
      setTimeout(done, 100)

    before initialize

    it 'expects change', (done) ->
      sw.once('stateChanged', (err, state) ->
        expect(state.video.ME[0].upstreamKeyNextBackground).be.false
        done err, null
      )
      sw.changeUpstreamKeyNextState(0, true)
      sw.changeUpstreamKeyNextBackground(false)

    after initialize

  describe 'changeUpstreamKeyNextState', ->
    initialize = (done) ->
      async.eachOfSeries(sw.state.video.ME[0].upstreamKeyNextState, (state, index, next) ->
        sw.changeUpstreamKeyNextState(index, false)
        next null, null
      )
      setTimeout(done, 1000)

    before initialize

    it 'expects change', (done) ->
      async.eachOfSeries(sw.state.video.ME[0].upstreamKeyNextState, (state, index, next) ->
        setTimeout( -> # temp
          expect(sw.state.video.ME[0].upstreamKeyNextState[index]).be.true
          next null, null
        , 100)
        sw.changeUpstreamKeyNextState(index, true)
      , done)

    after initialize

  describe 'changeAudioMasterGain', ->
    initialize = (done) ->
      sw.changeAudioMasterGain(0.5011853596610636)
      setTimeout(done, 100)

    before initialize

    it 'expects change', (done) ->
      sw.once('stateChanged', (err, state) ->
        expect(state.audio.master.gain).be.eq(1)
        done err, null
      )
      sw.changeAudioMasterGain(1)

    after initialize

  getAudioChannels = ->
    Object.keys(sw.state.audio.channels).reduce((arr, channel) ->
      arr.push(channel) if channel < 2000
      arr
    , [])

  describe 'changeAudioChannelGain', ->
    initialize = (done) ->
      async.eachSeries(getAudioChannels(), (channel, next) ->
        sw.changeAudioChannelGain(channel, 0.5011853596610636)
        setTimeout(next, 50)
      )
      setTimeout(done, 1000)

    before initialize

    it 'expects change', (done) ->
      async.eachSeries(getAudioChannels(), (channel, next) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.audio.channels[channel].gain).be.eq(1)
          next err, null
        )
        sw.changeAudioChannelGain(channel, 1)
      , done)

    after initialize

  describe 'changeAudioChannelState', ->
    initialize = (done) ->
      async.eachSeries(getAudioChannels(), (channel, next) ->
        sw.changeAudioChannelState(channel, false)
        next null, null
      , done)

    before initialize

    it 'expects change', (done) ->
      async.eachSeries(getAudioChannels(), (channel, next) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.audio.channels[channel].on).be.true
          next err, null
        )
        sw.changeAudioChannelState(channel, true)
      , done)

    after initialize

  describe 'sendAudioLevelNumber', ->
    initialize = (done) ->
      sw.sendAudioLevelNumber(false)
      setTimeout(done, 100)

    before initialize

    it 'exists levels', (done) ->
      sw.once('stateChanged', (err, state) ->
        expect(state.audio.master.leftLevel).to.exist
        expect(state.audio.master.rightLevel).to.exist
        done err, null
      )
      sw.sendAudioLevelNumber()

    it 'exists levels', (done) ->
      async.eachSeries(getAudioChannels(), (channel, next) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.audio.channels[channel].leftLevel).to.exist
          expect(state.audio.channels[channel].rightLevel).to.exist
          next err, null
        )
        sw.sendAudioLevelNumber()
      , done)

    after initialize

  describe 'runMacro', ->
    before (done) ->
      sw.changeProgramInput(1)
      setTimeout(done, 100)

    it 'expects run macro', (done) ->
      sw.startRecordMacro(99, 'Test Macro', 'Hey! This is macro.')
      sw.changeProgramInput(2)
      sw.stopRecordMacro()
      sw.changeProgramInput(1)
      sw.runMacro(99)
      setTimeout( ->
        expect(sw.state.video.ME[0].programInput).be.eq(2)
        done null, null
      , 500)

    after (done) ->
      sw.deleteMacro(99)
      sw.changeProgramInput(1)
      setTimeout(done, 100)

  after ->
    console.log """\n-------- ATEM Information --------
      ATEM Model: #{sw.state._pin}(#{sw.state.model})
      ATEM Version: #{sw.state._ver0}.#{sw.state._ver1}
      Video Channels: #{Object.keys(sw.state.channels).join(', ')}
      Audio Channels: #{Object.keys(sw.state.audio.channels).join(', ')}
      Auxs: #{Object.keys(sw.state.video.auxs).join(', ')}
      ----------------------------------"""
