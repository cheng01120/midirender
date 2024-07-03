import javax.sound.midi.*;
import java.io.File;
import java.util.*;
import java.lang.Number.*;
import com.hamoid.*;

// 要渲染的midi文件。
String song = "暗里着迷";
String midi_filename = "D:/Cubase/MIDI/exported/secretadm.mid";
float  fps  = 30.0f;

// 定义window的size。
static final int   WinX   = 1366;
static final int   WinY   = 768;
static final int   PianoY = 168;  // 键盘的高度。
static final float speed  = 3.0f; // 划过屏幕的时间： 3秒。

// 一下为不可更改部分。

PFont myFont;
boolean saveVideo = true;
ArrayList<Float> noises;
float noise_xoff = 0.0f;

PImage background, saber, shadow;
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
ArrayList<Integer> keyPressed; // 按下的键。

class keyPos {  // 计算一个key在x方向的坐标以及宽度。
	public float x;
	public float w;
	public boolean isWhiteKey;
};

public void settings() {
	size(WinX, WinY);
}

void setup() {
	background = loadImage("sky.png");
	background.resize(WinX, WinY - PianoY);

	//String[] fontList = PFont.list();
  //printArray(fontList);
	myFont = createFont("SimHei", 72);
	textFont(myFont);
	//textAlign(CENTER, CENTER);

	shadow = loadImage("shadow3.png");
	saber  = loadImage("saber.png");
	saber.resize(WinX, 30);
	noises = new ArrayList<Float>();
	for(int  s = 0; s <= WinX -2; s += 2) {
		noises.add(map(noise(noise_xoff), 0, 1, -3, 3));
		noise_xoff += 0.05;
	}

	flowKeys   = new Vector<keyEvent>();
	keyPressed = new ArrayList<Integer>();

	loadMidi();

	if(flowKeys.size() == 0) { noLoop(); return; }

	println("vector size: " + flowKeys.size());
	println("Microseconds per tick: " + microSecPerTick);
	noStroke();
	if(saveVideo) {
		videoExport = new VideoExport(this, "hello.mp4");
		videoExport.setFfmpegPath("c:/ffmpeg/bin/ffmpeg.exe");
		videoExport.setMovieFileName("d:/Cubase/Videos/MIDI.mp4");
		//videoExport.setAudioFileName("d:/Cubase/Audio/passacaglia.wav");
		videoExport.setFrameRate(fps);
		videoExport.startMovie();
	}
}

// 画的顺序： 背景，方块，白键，按下的白键， 黑键， 按下的黑键。
void draw() {
	imageMode(CORNER);
	background(0);
	image(background, 0, 0);

	if(flowKeys.size() == 0)  return;

	// grid.
	stroke(30);
	strokeWeight(1);
	float w = 1.0f * WinX/52;
	for(int i = 2; i < 52; i += 7) {
		float xpos = i*w;
		line(xpos, 0, xpos, WinY - PianoY);
	}
	noStroke();
	if(frameCounter <= fps * 6) {
		drawSongName();
	}

	blendMode(SCREEN);
	drawTiles();
	blendMode(BLEND);
	drawKeyboard();


	fill(50);
	// the C4 note.
	textSize(w/2);
	text("C4", w*23 + 2, WinY - w/2);

	// watermark.
	textSize(20);
	text("JeffZhang520", 30, 30);

	if(saveVideo) videoExport.saveFrame();
	if(frameCounter >= totalFrames) {
		if(saveVideo) videoExport.endMovie();
		exit();
	}

	frameCounter++;
}

void keyPressed() {
	if(key == 'q') {
		if( (flowKeys.size() != 0) && saveVideo) videoExport.endMovie();
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

					// 添加前置时间。
					/*
					long tick0 = flowKeys.get(0).on;
					float ttt = tick0 * microSecPerTick - 9.0f * 1000000;
					if(ttt < 0) { // 6sec title + 3sec secreen.
						long  ti = -1 * round(ttt / microSecPerTick);
						for(keyEvent kkk : flowKeys) { 
							kkk.on  += ti;
							kkk.off += ti;
						}
					}
					*/

					for(keyEvent kkk : flowKeys) { 
						kkk.on  += 9 * 1000000 / microSecPerTick;    // 7s text + 3s flow
						kkk.off += 9 * 1000000 / microSecPerTick;
					}
				} // if flowKeys.size();
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



void drawSaber() {  // inside drawkeyboard ( coordinate same as drawkeyboard );
  // We are going to draw a polygon out of the wave points
	tint(123, 11, 194, 96);
	image(saber, 0, -15);
	noTint();
	stroke(255);
	strokeWeight(2);

  beginShape(LINES); 
	vertex(0, noises.get(noises.size() - 1));

  for (int x = 2; x < WinX; x += 2) { // Iterate over horizontal pixels
		float y = noises.get(noises.size() -1 - x/2);
    vertex(x, y); 
    vertex(x, y); 
  }
  // increment y dimension for noise
  vertex(width, noises.get(0));
  endShape(CLOSE);
	noStroke();

	noises.remove(0);
	noises.add(map(noise(noise_xoff), 0, 1, -3, 3));
	noise_xoff += 0.05;
}

void drawKeyboard() {
	pushMatrix();
	resetMatrix();
	translate(0, WinY - PianoY);
	// white keys.
	fill(255, 255, 255);
	stroke(0, 0, 0);
	for(int i = 0; i < 88; i++) {
		keyPos pos = keyPosition(21 +i);
		if(pos.isWhiteKey) {
			rect(pos.x, 0, pos.w, PianoY);
		}
	}
	noStroke();

	// pressed white key.
	if(keyPressed.size() != 0) {
		fill(0, 255, 0);
		for(int key : keyPressed) {
			keyPos pos = keyPosition(key);
			if(pos.isWhiteKey) rect(pos.x, 0, pos.w, PianoY);
		}
	}

	// black keys
	fill(0, 0, 0);
	for(int i = 0; i < 88; i++) {
		keyPos pos = keyPosition(21 +i);
		if(!pos.isWhiteKey) {
			rect(pos.x, 0, pos.w, PianoY * 0.6f);
		}
	}

	// pressed black keys.
	if(keyPressed.size() != 0) {
		fill(255, 0, 0);
		for(int key : keyPressed) {
			keyPos pos = keyPosition(key);
			if(!pos.isWhiteKey) rect(pos.x, 0, pos.w, PianoY * 0.6f);
		}
	}

	drawSaber();
	popMatrix();
}

/*
时间线：
     up                       t0
      _________________________
      | (0,  0)               |
      |                       |
      |                       |
      |         WINDOW        |
      |                       |
      |                 (w,h) |
      _________________________
     down                     t1
*/

void drawTiles() {
	int Y = WinY - PianoY;
	keyPressed.clear();

	pushMatrix();
	resetMatrix();
	translate(0, Y);
	scale(1, -1);

	float t1 = 1000000 * frameCounter * 1.0f / fps;  // ms
	float t0 = t1 + speed * 1000000;

	color(255, 255, 255);
	noStroke();
	imageMode(CENTER);

	for(keyEvent ke : flowKeys) {
		float t_on  = ke.on  * microSecPerTick;
		float t_off = ke.off * microSecPerTick;

		if(t_on > t0 || t_off < t1) continue;

		//将时间转换为像素坐标。
		float y = (t_on - t1)    * Y / (speed * 1000000); // Y坐标。
		float h = (t_off - t_on) * Y / (speed * 1000000); // 高度（ 长度？）

		if(y <= 0.0f) { // 方块已经触及到了键盘。
			h += y; 
			y = 0.0f; 
			keyPressed.add(ke.key);
		}

		keyPos pos = keyPosition(ke.key);
		color clr = keyColor[ ke.key % 12 ];
		tint(clr);
		fill(clr);
		image(shadow, pos.x + pos.w/2, y + h/2, pos.w + 10, h);
		rect(pos.x, y, pos.w, h);
	}
	noTint();
	imageMode(CORNER);
	popMatrix();
}

void drawSongName() {
	textSize(72);

	float strWidth = textWidth(song);
	float strAscent = textAscent();
	float strDescent = textDescent();
	float strHeight = strAscent + strDescent;

	//rect(x, y - strAscent, strWidth, strHeight);
	float x = (WinX - strWidth)/2.0f;
	float y = (WinY - PianoY - strHeight) /2.0f;

	float opacity;
	if(frameCounter <= fps *2)  {// 3 sec fade in.
		opacity = map(frameCounter, 0, fps * 3, 0, 255);
	}
	else if(frameCounter <= fps * 4) { 
		opacity = 255;
	}
	else {
		opacity = map(frameCounter - fps * 4, 0, fps * 2, 0, 255);  // 2 sec fade out.
		opacity = 255 - opacity;
	}

	fill(255, 255, 255, opacity);
	text(song, x, y);
}
