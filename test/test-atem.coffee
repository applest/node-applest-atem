async  = require 'async'
chai   = require 'chai'
expect = chai.expect
(require 'it-each')()

ATEM   = require '../lib/atem'

ATEM_ADDR = process.env['ATEM_ADDR'] || '172.16.0.2'
ATEM_PORT = process.env['ATEM_PORT'] || 9910

describe 'Atem', ->
  sw = new ATEM

  before (done) ->
    sw.once('ping', ->
      sw.once('stateChanged', done)
    ) # Change me
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
          expect(state.video.programInput).be.eq(input)
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
          expect(state.video.previewInput).be.eq(input)
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
      sw.fadeToBlack() if sw.state.video.fadeToBlack
      setTimeout(done, 1500)

    it 'expects fade to black', (done) ->
      setTimeout( ->
        expect(sw.state.video.fadeToBlack).be.true
        done null, null
      , 1500)
      sw.fadeToBlack()

    it 'expects restore fade to black', (done) ->
      setTimeout( ->
        expect(sw.state.video.fadeToBlack).be.false
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
      expect(sw.state.video.programInput).be.eq(1)
      expect(sw.state.video.previewInput).be.eq(2)

    it 'expects swap program and preview input', (done) ->
      setTimeout( ->
        expect(sw.state.video.programInput).be.eq(2)
        expect(sw.state.video.previewInput).be.eq(1)
        done null, null
      , 1500)
      sw.autoTransition()

  describe 'cutTransition', ->
    before (done) ->
      sw.changeProgramInput(1)
      sw.changePreviewInput(2)
      setTimeout(done, 100)

    it 'expects set program and preview input', ->
      expect(sw.state.video.programInput).be.eq(1)
      expect(sw.state.video.previewInput).be.eq(2)

    it 'expects swap program and preview input', (done) ->
      sw.once('stateChanged', (err, state) ->
        expect(state.video.programInput).be.eq(2)
        expect(state.video.previewInput).be.eq(1)
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
        expect(state.video.transitionPosition).be.eq(0.5)
        done err, null
      )
      sw.changeTransitionPosition(5000)

    after initialize

  describe 'changeTransitionPreview', ->
    initialize = (done) ->
      sw.changeTransitionPreview(false) if sw.state.video.transitionPreview
      setTimeout(done, 100)

    before initialize

    it 'expects false', ->
      expect(sw.state.video.transitionPreview).be.false

    it 'expects true when enable', (done) ->
      sw.once('stateChanged', (err, state) ->
        expect(state.video.transitionPreview).be.true
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
          expect(state.video.transitionStyle).be.eq(type)
          next err, null
        )
        sw.changeTransitionType(type)
      , done)

  describe 'changeUpstreamKeyState', ->
    initialize = (done) ->
      async.forEachOfSeries(sw.state.video.upstreamKeyState, (state, index, next) ->
        sw.changeUpstreamKeyState(index, false)
        next null, null
      )
      setTimeout(done, 100)

    before initialize

    it 'expects change', (done) ->
      async.forEachOfSeries(sw.state.video.upstreamKeyState, (state, index, next) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.video.upstreamKeyState[index]).be.true
          next null, null
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
        expect(state.video.upstreamKeyNextBackground).be.false
        done null, null
      )
      sw.changeUpstreamKeyNextState(0, true)
      sw.changeUpstreamKeyNextBackground(false)

    after initialize

  describe 'changeUpstreamKeyNextState', ->
    initialize = (done) ->
      async.forEachOfSeries(sw.state.video.upstreamKeyNextState, (state, index, next) ->
        sw.changeUpstreamKeyNextState(index, false)
        next null, null
      )
      setTimeout(done, 100)

    before initialize

    it 'expects change', (done) ->
      async.forEachOfSeries(sw.state.video.upstreamKeyNextState, (state, index, next) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.video.upstreamKeyNextState[index]).be.true
          next null, null
        )
        sw.changeUpstreamKeyNextState(index, true)
      , done)

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
        next null, null
      , done)

    before initialize

    it 'expects change', (done) ->
      async.eachSeries(getAudioChannels(), (channel, next) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.audio.channels[channel].gain).be.eq(1)
          next null, null
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

  after ->
    console.log """\n-------- ATEM Information --------
      ATEM Model: #{sw.state._pin}(#{sw.state.model})
      ATEM Version: #{sw.state._ver0}.#{sw.state._ver1}
      Video Channels: #{Object.keys(sw.state.channels).join(', ')}
      Audio Channels: #{Object.keys(sw.state.audio.channels).join(', ')}
      Auxs: #{Object.keys(sw.state.video.auxs).join(', ')}
      ----------------------------------"""
