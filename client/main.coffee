
Template.main.rendered = ->
  window.spectogram = Spectogram('waterfall')#, 60, 350)



navigator.getUserMedia = navigator.getUserMedia or
                         navigator.webkitGetUserMedia or
                         navigator.mozGetUserMedia or
                         navigator.msGetUserMedia

window.requestAnimationFrame = window.requestAnimationFrame or
                         window.webkitRequestAnimationFrame or
                         window.mozRequestAnimationFrame or
                         window.msRequestAnimationFrame




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




Spectogram = (canvasId, minFreq=0, maxFreq=4410) ->
  # Creates a spectogram visualizer for microphone input. This
  # requires a call to getUserMedia which is currently only
  # available in Chrome and Firefox.


  # Currently the maximum frequency is 4410Hz because we downsample
  # by a factor of 5. We store the FFT values in a 1024 bit array
  # which gives us a resolution of 4410 Hz / 1024 pixels.
  k = 4410/1024

  # Given the frequency range we want to display, we need to calculate
  # the index of the array we want to display
  maxFreqIndex = Math.round(maxFreq/k)
  minFreqIndex = Math.round(minFreq/k)
  freqRangeLength = maxFreqIndex - minFreqIndex


  hot = chroma.scale ['#000000', '#0B16B5', '#FFF782', '#EB1250'],
                     [0,          0.4,       0.68,          0.85]
          .mode 'rgb'
          .domain [0, 300]

  # get the context from the canvas to draw on
  $canvas = $("#" + canvasId)
  overlayElement = $("#" + canvasId + "-overlay")
  canvas = document.getElementById(canvasId)

  ctx = $canvas.get()[0].getContext("2d")

  # create a temp canvas we use for copying
  tempCanvas = document.createElement("canvas")

  tempCtx = tempCanvas.getContext("2d")
  canvas.width = freqRangeLength + 1
  tempCanvas.width = freqRangeLength + 1
  # tempCanvas.width=1024
  tempCanvas.height=256

  scriptNodes = {}
  nextNodeID = 1
  keep = (node) ->
    node.id = node.id or (nextNodeID++)
    scriptNodes[node.id] = node
    return node

  drop = (node) ->
      delete scriptNodes[node.id]
      return node

  array = new Uint8Array(1024)
  obj.array = array

  initAudio = (stream) ->
    context = new AudioContext()
    obj.context = context

    # Create an AudioNode from the stream (live input)
    sourceNode = context.createMediaStreamSource(stream)
    obj.sourceNode = sourceNode
    # Filter the audio to limit bandwidth to 4kHz before resampling,
    # by using a BiQuadFilterNode:
    filterNode = context.createBiquadFilter()
    filterNode.type = filterNode.LOWPASS
    filterNode.frequency.value = 3800
    filterNode.Q.value = 1.5
    filterNode.gain.value = 0
    obj.filterNode = filterNode

    sourceNode.connect(filterNode)

    # Create an audio resampler:
    resamplerNode = keep context.createScriptProcessor(8192,1,1)

    rss = new Resampler(44100, 8820, 1, 1639, true)
    resamplerNode.onaudioprocess = (event) ->
      inp = event.inputBuffer.getChannelData(0)
      out = event.outputBuffer.getChannelData(0)
      l = rss.resampler(inp)
      # We can edit the values of the array, but not change the reference -
      # if we do, it won't do anything, the audioBuffer will keep its internal
      # reference: therefore we need to manually copy all samples:
      for i in [0...l]
        out[i] = rss.outputBuffer[i]

    filterNode.connect(resamplerNode)

    #Create an audio analyser:
    analyser = context.createAnalyser()
    analyser.smoothingTimeConstant = 0
    analyser.fftSize = 2048

    obj.anaylser = analyser

    # Then connect the analyser to the resampler node
    # The issue here is, that the analyser is going to get input
    # buffers that are only filled up to 1639 samples, the rest being
    # silence, since we have a sample rate mismatch after the resampler node.
    resamplerNode.connect(analyser)

    # requestAnimationFrame(drawSpectrogram)

    syncDisplay  = keep context.createScriptProcessor(2048,1,1)
    syncDisplay.onaudioprocess = ->
      # get the average for the first channel
      analyser.getByteFrequencyData(array)
      requestAnimationFrame(drawSpectrogram)

    syncDisplay.connect(context.destination)


  # monitoring = false
  # obj.monitor = (turnOn) ->
  #   if turnOn
  #     if not monitoring
  #       obj.sourceNode.connect obj.context.destination
  #       monitoring = not monitoring
  #   else
  #     if monitoring
  #       obj.sourceNode.disconnect()
  #       obj.sourceNode.connect obj.filterNode
  #       monitoring = not monitoring


  emptyLine = 0
  continuous = true
  drawSpectrogram = ->
    # The analyzer is in constant underrun because it assumes
    # we have a 44.1kHz sample rate, and we downsampled 5 times to
    # 8820.

    # Therefore I check if I didn't only get zeroes in the array, and if I did,
    # I just return.
    pwr = 0
    # max = 0
    # maxIndex = 0
    for i in [0...1024]
        pwr += array[i]
        # if array[i] > max
          # max = array[i]
          # maxIndex = i

    if continuous
      # because we downsample 5, we need to throw out the empty values
      # however, this stops the whole thing when theres no audio, so check
      # if there are 5 in a row and print it out so it looks continuous
      if not pwr
        emptyLine += 1
        if emptyLine < 5
          return
        else
          emptyLine = 0
      else
        emptyLine = 0
    else
      if not pwr then return

    # copy the current canvas onto the temp canvas
    tempCtx.drawImage(canvas, 0, 0, freqRangeLength+1, 256)

    # Each pixel is 4500/1024 = 4.39Hz wide
    # iterate over the elements from the array
    for i in [0...array.length]
      # draw each pixel with the specific color
      value = array[i]
      # ctx.fillStyle = chroma.scales.hot()(value/300).hex()
      ctx.fillStyle = hot(value).hex()
      # draw the line on top of the canvas
      if i >= minFreqIndex and i <= maxFreqIndex
        ctx.fillRect(i-minFreqIndex, 1, 1, 1)

    # draw the copied image
    # ctx.drawImage(tempCanvas, 0, 0, 1024, 256, 0, 1, 1024, 256)
    ctx.drawImage(tempCanvas, 0, 0,  freqRangeLength+1, 256, 0, 1,  freqRangeLength+1, 256)


  started = false
  microphoneError = (event) ->
    console.log event
    if event.name is "PermissionDeniedError"
      alert "This app requires a microphone as input. Please adjust your privacy settings."

  microphoneSuccess = (stream) ->
    started = true
    overlayElement.css 'opacity', '0'
    initAudio(stream)

  paused = false
  $canvas.on 'click', (e) ->
    if started
      if paused
        obj.sourceNode.connect obj.filterNode
        overlayElement.css 'opacity', '0'
        paused = false
      else
        obj.sourceNode.disconnect()
        overlayElement.css 'opacity', '1'
        paused = true
    else
      if navigator.getUserMedia
        navigator.getUserMedia {audio: true}, microphoneSuccess, microphoneError
      else
        alert "This app requires a microphone as input. Please try using Chrome or Firefox."

  return obj
