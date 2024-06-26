import javax.sound.midi.*;
import java.io.File;
import java.util.*;
import java.lang.Number.*;
import com.hamoid.*;

// 定义window的size。
static final int   WinX   = 1366;
static final int   WinY   = 768;
static final int   PianoY = 168;  // 键盘的高度。
static final float speed  = 3.0f; // 划过屏幕的时间： 3秒。

// 要渲染的midi文件。
String midi_filename = "D:/Cubase/MIDI/exported/passacaglia.mid";
float  fps  = 29.97f;

PImage background;
long frameCounter = 0;
long totalFrames  = 0;
float microSecPerTick = 0.0f;
VideoExport videoExport;


static final color[] keyColor = { 
	#a1ab20, #234fbe, #ab205b, #1a8cca, 
	#234fbe, #ab9820, #20ab73, #ab8b20, 
	#2058ab, #3a23be, #9c20ab, #2069ab 
};

class keyEvent {
	int key;  // note
	long on;  // note on in ticks
	long off; // note off in ticks
};
Vector<keyEvent> flowKeys;

class keyPos {  // 计算一个key在x方向的坐标以及宽度。
	public float x;
	public float w;
	public boolean isWhiteKey;
};

public void settings() {
	size(WinX, WinY);
}

void setup() {
	background = loadImage("bg.png");
	background.resize(WinX, WinY);

	flowKeys = new Vector<keyEvent>();
	loadMidi();

	if(flowKeys.size() == 0) { noLoop(); return; }

	println("vector size: " + flowKeys.size());
	println("Microseconds per tick: " + microSecPerTick);
	noStroke();
	videoExport = new VideoExport(this, "hello.mp4");
	videoExport.setFfmpegPath("c:/ffmpeg/bin/ffmpeg.exe");
	videoExport.setMovieFileName("d:/Cubase/Videos/MIDI.mp4");
	//videoExport.setAudioFileName("d:/Cubase/Audio/passacaglia.wav");
	videoExport.setFrameRate(fps);
	videoExport.startMovie();
}

/*
	up                         t0
    ________________________ 
	  | (0, 0)               |
	  |                      |
	  |                      |
	  |                      |
	  |                      |
	  |                (w,h) |
    ________________________
	down                     t1
*/

void draw() {
	background(0);

	resetMatrix();
	image(background, 0, 0);
	drawKeyboard();
	if(flowKeys.size() == 0) return;

	translate(0, WinY - PianoY); scale(1, -1);

	float t1 = 1000000 * frameCounter * 1.0f / fps;  // ms
	float t0 = t1 + speed * 1000000;  // 划过屏幕的时间： 3秒。

	for(int i = 0; i < flowKeys.size(); i ++) {
		keyEvent ke = flowKeys.get(i);
		color rectColor = keyColor[ ke.key % 12 ];
		keyPos pos = keyPosition(ke.key);

		float t_on  = ke.on  * microSecPerTick;
		float t_off = ke.off * microSecPerTick;

		if(t_on > t0 || t_off < t1) continue;

		//将时间转换为像素坐标。
		float y = (t_on - t1) * (WinY - PianoY)/(speed * 1000000);
		float h = (t_off - t_on) * (WinY - PianoY)/(speed * 1000000);

		if(y <= 0.0f) { // 方块已经触及到了键盘。
			h += y; 
			y = 0.0f; 

			// 改变下方琴键的颜色。
			if(!pos.isWhiteKey) {
				fill(255, 0, 0);
				rect(pos.x, -PianoY*0.6f, pos.w, PianoY*0.6f); 
			}
			else {
				fill(0, 255, 0);
				rect(pos.x, -PianoY* 1.0f, pos.w,  PianoY * 1.0f);
			}
		}
		// 方块。

		fill(#eeeeee);
		rect(pos.x, y, pos.w, h);
	}

	videoExport.saveFrame();
	if(frameCounter >= totalFrames) {
		videoExport.endMovie();
		exit();
	}
	frameCounter++;
}

void keyPressed() {
	if(key == 'q') {
		if(flowKeys.size() != 0) videoExport.endMovie();
		exit();
	}
}

void loadMidi() {
	File f = new File(midi_filename);
	try {
			Sequence s = MidiSystem.getSequence(f);
			println("Division type: " + s.getDivisionType());
			println("Duration (ticks): " + s.getTickLength());
			println("Duration (microsec): " + s.getMicrosecondLength());
			println("Resolution: " + s.getResolution());
			totalFrames = round(s.getMicrosecondLength() * fps / 1000000 + 3*fps); //增加三秒时长。
			println("Total frames: " + totalFrames);
			microSecPerTick = s.getMicrosecondLength() * 1.0f / s.getTickLength();

			Track[] tracks = s.getTracks();
			println("Tracks: " + tracks.length);

			for(int i = 0; i < tracks.length; i++) {
				Track t = tracks[i];
				println("  Track " + (i+1));
				println("    Events: " + t.size());
				println("    Duration (ticks): " + t.ticks());

				//long ticksum = 0;
				if(t.size() < 20) continue;

				for(int j = 0; j < t.size(); j++) {
					MidiEvent   e    = t.get(j);
					MidiMessage m    = e.getMessage();
					long        tick = e.getTick();

					byte[] data = m.getMessage();
					int key1   = data[1];
					int status = m.getStatus();
					// note on = 0x9 , note off = 0x8
					if( (status >> 4) == 0x09 ) {
						keyEvent ke = new keyEvent();
						ke.key = key1;
						ke.on  = tick;
						ke.off = 0;
						flowKeys.add(ke);
					}
					else if( (status >> 4 ) == 0x08 ) {
						for(int k = flowKeys.size() -1; k >= 0; k-- ) { //查找noteon的key
							keyEvent ke = flowKeys.get(k);
							if(ke.key == key1 && ke.off == 0) {  
									ke.off = tick; // 找到最近一个没有noteoff的key
									//flowKeys.set(k, ke);  // 不需要set
									break;
								}
							}
						}
				} // track 

				if(flowKeys.size() != 0) { 
					// debug
					println("Last tick num: " + flowKeys.get(flowKeys.size()-1).off); 
					// 将没有off的key的off值设置为后一个key的on。
					for(int k = 0; k < flowKeys.size(); k++) {
						keyEvent ke = flowKeys.get(k);
						if(ke.off == 0 && k != (flowKeys.size() -1)) {
							ke.off = flowKeys.get(k+1).on;
						}
					}
					if(flowKeys.get(flowKeys.size() -1).off == 0) { flowKeys.remove(flowKeys.size() -1); }
				}
		}
	} catch(Exception e) { println("Unable to load midi file."); } 
} // loadMidi


keyPos keyPosition(long key) {
	keyPos pos = new keyPos();
	pos.x = 0;
	pos.w = 0;
	pos.isWhiteKey = false;

	float whiteKeyWidth = 1.0f * WinX / 52.0f; // 52 white key , 36 black key.
	long n = whiteKeyNumber(key);
	if(n != -1) {
		pos.x = n * whiteKeyWidth;
		pos.w = whiteKeyWidth;
		pos.isWhiteKey = true;
	}
	else {
		key -= 1; // 如果是黑键，那么找出低一级白健的位置。
		n = whiteKeyNumber(key);
		pos.x = (n + 0.667f) * whiteKeyWidth;
		pos.w = 0.667 * whiteKeyWidth;
	}

	return pos;
}

long whiteKeyNumber(long key) { // 查找是第几个白键， 如果是黑键返回-1
	key -= 21;
	if(key == 0) {
		return 0;
	}
	else if(key == 2) {
		return 1;
	}
	else if(key == 87) {
		return 51;
	}
	else {
		key -= 3;

		long m = key % 12;
		long n = (key - m)/12;
		boolean isWhiteKey = false;

		long[] white = { 0, 2, 4, 5, 7, 9, 11 };
		int i = 0;  // 是第几个白键。
		for( long elem : white) {
			if(elem == m) {
				isWhiteKey = true;
				break;
			}
			i++;
		}

		if(!isWhiteKey) return -1;

		return n * 7 + i + 2; 
	}
}

void drawKeyboard() {
	pushMatrix();
	resetMatrix();

	translate(0, WinY - PianoY);

	float t1 = WinX * 1.0f / 52; // 52 white keys.
	for(int i = 0; i < 52; i++) {
		fill(255, 255, 255);
		rect(i * t1, 0, t1, PianoY);
	}

  // draw the first black keys.  width of black key = 2 * whitekey / 3, height = 0.6 * whitekey
	float t2 = t1 * 0.6667;
	fill(0, 0, 0);
	rect(t1 * 0.667, 0, t1 * 0.667, PianoY * 0.6);


	float start = t1 * 2;

	int[] blackkey_id = { 0, 1, 3, 4, 5 };
	for(int i =0; i < 7; i++) { // draw the left 35 black keys.
		for( int id : blackkey_id) {
			int offset = 2 + i * 7 + id;
			rect( (1.0f * offset + 0.667) * t1, 0, t1 * 0.667, PianoY * 0.6);
		}
	}

	popMatrix();
}
