
Template.main.rendered = ->
  Spectogram('waterfall')





# 440 -> 102
# 1000 -> 232
# 2000 -> 463
# 3000 -> 595
# 4000 -> 929
# 4300 -> 998
# 4.306640625

# 1 (E)	329.63 Hz	E4
# 2 (B)	246.94 Hz	B3
# 3 (G)	196.00 Hz	G3
# 4 (D)	146.83 Hz	D3
# 5 (A)	110.00 Hz	A2
# 6 (E)	82.41 Hz	E2
# drop d 73.42


navigator.getUserMedia = navigator.getUserMedia or
                         navigator.webkitGetUserMedia or
                         navigator.mozGetUserMedia or
                         navigator.msGetUserMedia

window.requestAnimationFrame = window.requestAnimationFrame or
                         window.webkitRequestAnimationFrame or
                         window.mozRequestAnimationFrame or
                         window.msRequestAnimationFrame

Spectogram = (canvasId) ->
  # Creates a spectogram visualizer for microphone input. This
  # requires a call to getUserMedia which is currently only
  # available in Chrome and Firefox.

  minFreq=0
  maxFreq=4410

  # We get 44100 Hz input from the microphone. So we'll want to subsample
  # to compute the specific frequency range we're interested in. We'll have
  # to round to the closest integer subsample rate. Also note the Nyquist
  # frequency requires a factor of two when sampling.
  inputSampleRate = 44100
  subsampleFactor = Math.floor(44100/maxFreq/2) # 5
  resampleRate = inputSampleRate/subsampleFactor # 8820
  resampleMaxFreq = resampleRate/2 # 4410

  # Compute the frequency / pixel resolution. Note that we must calculate
  # all frequencies down to zero so raising the minFreq doesn't change the
  # resolution
  pixelResolution = resampleMaxFreq/1024

  # Given the frequency range we want to display, we need to calculate
  # the index of the 1024 element array we want to display.
  maxFreqIndex = Math.round(maxFreq/pixelResolution)
  minFreqIndex = Math.round(minFreq/pixelResolution)

  # compute the width of the canvas to display all these frequencies
  width = maxFreqIndex - minFreqIndex + 1

  # get the context from the canvas to draw on
  $canvas = $("#" + canvasId)
  $overlay = $("#" + canvasId + "-overlay")

  # get the context of the canvas element
  canvas = document.getElementById(canvasId)
  ctx = canvas.getContext("2d")

  # create another canvas to use for copying
  tempCanvas = document.createElement("canvas")
  tempCtx = tempCanvas.getContext("2d")

  canvas.width = width
  canvas.height=256
  tempCanvas.width = width
  tempCanvas.height=256


  # array = new Uint8Array(1024)


  # define some variables in the outer context to be defined
  # in initAudio but also used elsewhere
  context = null
  sourceNode = null
  filterNode = null
  fft = null
  fftWindow = DSP.HAMMING
  spectrumbuffer = []
  maxAvg = 1 # smoothing
  gain=45
  floor = 40
  initAudio = (stream) ->
    context = new AudioContext()
    fft = new FFT(2048, resampleRate)

    # Create an AudioNode from the input stream
    sourceNode = context.createMediaStreamSource(stream)

    # Filter the audio to limit bandwidth to before resampling to prevent
    # aliasing using a Biquad Filter.
    filterNode = context.createBiquadFilter()
    filterNode.type = filterNode.LOWPASS
    filterNode.frequency.value = 0.95*maxFreq
    filterNode.Q.value = 1.5
    filterNode.gain.value = 0

    # pass the sourceNode into the filterNode
    sourceNode.connect(filterNode)


    # Create an audio resampler
    resamplerNode = context.createScriptProcessor(4096,1,1)
    rss = new Resampler(44100, resampleRate, 1, 4096, true)
    ring = new Float32Array(4096)
    fftbuffer = new Float32Array(2048)
    idx = 0
    spectrumidx = 0
    dspwindow = new WindowFunction(fftWindow)

    resamplerNode.onaudioprocess = (event) ->
      inp = event.inputBuffer.getChannelData(0)
      out = event.outputBuffer.getChannelData(0)
      l = rss.resampler(inp)

      for i in [0...l]
        ring[(i+idx)%4096] = rss.outputBuffer[i]

      #Now copy the oldest 2048 bytes from ring buffer to the output channel
      for i in [0...2048]
          fftbuffer[i] = ring[(idx+i+2048)%4096]


      idx = (idx+l)%4096
      # Before doing our FFT, we apply a window to attenuate frequency artifacts,
      # otherwise the spectrum will bleed all over the place:
      dspwindow.process(fftbuffer)

      fft.forward(fftbuffer)
      spectrumbuffer[spectrumidx] = new Float32Array(fft.spectrum)
      spectrumidx = (spectrumidx+1)%maxAvg
      requestAnimationFrame(drawSpectrogram)


    filterNode.connect(resamplerNode)
    resamplerNode.connect(context.destination)


  hot = chroma.scale ['#000000', '#0B16B5', '#FFF782', '#EB1250'],
                     [0,          0.4,       0.68,          0.85]
          .mode 'rgb'
          .domain [0, 300]

  emptyLine = 0
  continuous = true
  drawSpectrogram = ->
    tempCtx.drawImage(canvas, 0, 0, 1024, 256)
    # Spectrogram clear
    # ctx.clearRect(0, 0, 1024, 256)
    # set the fill style
    # ctx.fillStyle=gradient
    # ctx.beginPath()
    # ctx.moveTo(0, 256)

    for i in [0...1024]
        # draw each pixel with the specific color
        sp = 0
        for j in [0...maxAvg]
          sp += spectrumbuffer[j][i]

        value = 256 + gain*Math.log(sp/maxAvg*floor)
        # draw the line on top of the canvas
        ctx.fillStyle = hot(value).hex()
        ctx.fillRect(i, 1, 1, 1)
        # if not (i % 4)
        #     #ctx.fillRect(i,256-value,3,256);
        #     ctx.lineTo(i,256-value)
        #     ctx.stroke()

    # draw the copied image
    ctx.drawImage(tempCanvas, 0, 0, 1024, 256, 0, 1, 1024, 256);


  started = false
  microphoneError = (event) ->
    console.log event
    if event.name is "PermissionDeniedError"
      alert "This app requires a microphone as input. Please adjust your privacy settings."

  microphoneSuccess = (stream) ->
    started = true
    $overlay.css 'opacity', '0'
    initAudio(stream)

  paused = false
  $canvas.on 'click', (e) ->
    if started
      if paused
        sourceNode.connect filterNode
        $overlay.css 'opacity', '0'
        paused = false
      else
        sourceNode.disconnect()
        $overlay.css 'opacity', '1'
        paused = true
    else
      if navigator.getUserMedia
        navigator.getUserMedia {audio: true}, microphoneSuccess, microphoneError
      else
        alert "This app requires a microphone as input. Please try using Chrome or Firefox."
