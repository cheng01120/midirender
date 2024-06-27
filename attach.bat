ffmpeg -i d:/Cubase/Videos/MIDI.mp4 -i d:/Cubase/Audio/passacaglia.wav -c:v copy -map 0:v -map 1:a -shortest output.mp4
