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
    initialize = (done) ->
      for me in [0...sw.state.topology.numberOfMEs]
        sw.changeProgramInput(1, me)
      setTimeout(done, 100)

    before initialize

    it 'expects change all camera input', (done) ->
      async.eachSeries([0...sw.state.topology.numberOfMEs], (me, nextME) ->
        async.eachSeries(getCameraInputs(), (input, next) ->
          sw.once('stateChanged', (err, state) ->
            expect(state.video.ME[me].programInput).be.eq(input)
            next err, null
          )
          sw.changeProgramInput(input, me)
        , nextME)
      , done)

    after initialize

  describe 'changePreviewInput', ->
    initialize = (done) ->
      for me in [0...sw.state.topology.numberOfMEs]
        sw.changePreviewInput(1, me)
      setTimeout(done, 100)

    before initialize

    it 'expects change all camera input', (done) ->
      async.eachSeries([0...sw.state.topology.numberOfMEs], (me, nextME) ->
        async.eachSeries(getCameraInputs(), (input, next) ->
          sw.once('stateChanged', (err, state) ->
            expect(state.video.ME[me].previewInput).be.eq(input)
            next err, null
          )
          sw.changePreviewInput(input, me)
        , nextME)
      , done)

    after initialize

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
      for me in [0...sw.state.topology.numberOfMEs]
        sw.fadeToBlack(me) if sw.state.video.ME[me].fadeToBlack
      setTimeout(done, 1500)

    it 'expects fade to black', (done) ->
      async.eachSeries([0...sw.state.topology.numberOfMEs], (me, nextME) ->
        setTimeout( ->
          expect(sw.state.video.ME[me].fadeToBlack).be.true
          nextME null, null
        , 1500)
        sw.fadeToBlack(me)
      , done)

    it 'expects restore fade to black', (done) ->
      async.eachSeries([0...sw.state.topology.numberOfMEs], (me, nextME) ->
        setTimeout( ->
          expect(sw.state.video.ME[me].fadeToBlack).be.false
          nextME null, null
        , 1500)
        sw.fadeToBlack(me)
      , done)

  describe 'autoTransition', ->
    before (done) ->
      for me in [0...sw.state.topology.numberOfMEs]
        sw.changeTransitionType(ATEM.TransitionStyle.MIX, me)
        sw.changeProgramInput(1, me)
        sw.changePreviewInput(2, me)
      setTimeout(done, 100)

    it 'expects set program and preview input', ->
      for me in [0...sw.state.topology.numberOfMEs]
        expect(sw.state.video.ME[me].programInput).be.eq(1)
        expect(sw.state.video.ME[me].previewInput).be.eq(2)

    it 'expects swap program and preview input', (done) ->
      async.eachSeries([0...sw.state.topology.numberOfMEs], (me, nextME) ->
        setTimeout( ->
          expect(sw.state.video.ME[me].programInput).be.eq(2)
          expect(sw.state.video.ME[me].previewInput).be.eq(1)
          nextME null, null
        , 1500)
        sw.autoTransition(me)
      , done)

  describe 'cutTransition', ->
    before (done) ->
      for me in [0...sw.state.topology.numberOfMEs]
        sw.changeProgramInput(1, me)
        sw.changePreviewInput(2, me)
      setTimeout(done, 100)

    it 'expects set program and preview input', ->
      for me in [0...sw.state.topology.numberOfMEs]
        expect(sw.state.video.ME[me].programInput).be.eq(1)
        expect(sw.state.video.ME[me].previewInput).be.eq(2)

    it 'expects swap program and preview input', (done) ->
      async.eachSeries([0...sw.state.topology.numberOfMEs], (me, nextME) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.video.ME[me].programInput).be.eq(2)
          expect(state.video.ME[me].previewInput).be.eq(1)
          nextME err, null
        )
        sw.cutTransition(me)
      , done)

  describe 'changeTransitionPosition', ->
    initialize = (done) ->
      for me in [0...sw.state.topology.numberOfMEs]
        sw.changeTransitionPosition(0, me)
      setTimeout(done, 100)

    before initialize

    it 'expects change transition position', (done) ->
      async.eachSeries([0...sw.state.topology.numberOfMEs], (me, nextME) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.video.ME[me].transitionPosition).be.eq(0.5)
          nextME err, null
        )
        sw.changeTransitionPosition(5000, me)
      , done)

    after initialize

  describe 'changeTransitionPreview', ->
    initialize = (done) ->
      for me in [0...sw.state.topology.numberOfMEs]
        sw.changeTransitionPreview(false, me) if sw.state.video.ME[me].transitionPreview
      setTimeout(done, 100)

    before initialize

    it 'expects false', ->
      for me in [0...sw.state.topology.numberOfMEs]
        expect(sw.state.video.ME[me].transitionPreview).be.false

    it 'expects true when enable', (done) ->
      async.eachSeries([0...sw.state.topology.numberOfMEs], (me, nextME) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.video.ME[me].transitionPreview).be.true
          nextME err, null
        )
        sw.changeTransitionPreview(true, me)
      , done)

    after initialize

  describe 'changeTransitionType', ->
    before (done) ->
      for me in [0...sw.state.topology.numberOfMEs]
        sw.changeTransitionType(ATEM.TransitionStyle.DIP, me)
      setTimeout(done, 100)

    it 'expects change all transition type', (done) ->
      types = if sw.state.model == ATEM.Model.TVS || sw.state.model == ATEM.Model.PS4K
        [ATEM.TransitionStyle.MIX, ATEM.TransitionStyle.DIP, ATEM.TransitionStyle.WIPE]
      else
        (v for k, v of ATEM.TransitionStyle)

      async.eachSeries([0...sw.state.topology.numberOfMEs], (me, nextME) ->
        async.eachSeries(types, (type, next) ->
          sw.once('stateChanged', (err, state) ->
            expect(state.video.ME[me].transitionStyle).be.eq(type)
            next err, null
          )
          sw.changeTransitionType(type, me)
        , nextME)
      done)

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

  describe 'downstreamKeyAuto', ->
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
        sw.downstreamKeyAuto(index)
      , done)

    after initialize

  describe 'changeUpstreamKeyState', ->
    initialize = (done) ->
      for me in [0...sw.state.topology.numberOfMEs]
        for keyer in [0...sw.state.video.ME[me].numberOfKeyers]
          sw.changeUpstreamKeyState(keyer, false, me)
      setTimeout(done, 100)

    before initialize

    it 'expects change', (done) ->
      async.eachSeries([0...sw.state.topology.numberOfMEs], (me, nextME) ->
        async.eachOfSeries(sw.state.video.ME[me].upstreamKeyState, (state, index, next) ->
          sw.once('stateChanged', (err, state) ->
            expect(state.video.ME[me].upstreamKeyState[index]).be.true
            next err, null
          )
          sw.changeUpstreamKeyState(index, true, me)
        , nextME)
      , done)

    after initialize

  describe 'changeUpstreamKeyNextBackground', ->
    initialize = (done) ->
      for me in [0...sw.state.topology.numberOfMEs]
        sw.changeUpstreamKeyNextState(0, false, me)
        sw.changeUpstreamKeyNextBackground(true, me)
      setTimeout(done, 100)

    before initialize

    it 'expects change', (done) ->
      async.eachSeries([0...sw.state.topology.numberOfMEs], (me, nextME) ->
        sw.once('stateChanged', (err, state) ->
          expect(state.video.ME[me].upstreamKeyNextBackground).be.false
          nextME err, null
        )
        sw.changeUpstreamKeyNextState(0, true, me)
        sw.changeUpstreamKeyNextBackground(false, me)
      , done)

    after initialize

  describe 'changeUpstreamKeyNextState', ->
    initialize = (done) ->
      for me in [0...sw.state.topology.numberOfMEs]
        for keyer in [0...sw.state.video.ME[me].numberOfKeyers]
          sw.changeUpstreamKeyNextState(keyer, false, me)
      setTimeout(done, 1000)

    before initialize

    it 'expects change', (done) ->
      async.eachSeries([0...sw.state.topology.numberOfMEs], (me, nextME) ->
        async.eachOfSeries(sw.state.video.ME[me].upstreamKeyNextState, (state, index, next) ->
          sw.once('stateChanged', (err, state) ->
            expect(sw.state.video.ME[me].upstreamKeyNextState[index]).be.true
            next err, null
          )
          sw.changeUpstreamKeyNextState(index, true, me)
        , nextME)
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
