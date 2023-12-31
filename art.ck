// Initialize Mouse Manager ===================================================
Mouse mouse;
spork ~ mouse.start(0);  // start listening for mouse events
spork ~ mouse.selfUpdate(); // start updating mouse position


// Global Sequencer Params ====================================================

30 => int BPM;  // beats per minute
(1.0/BPM)::minute / 2.0 => dur STEP;  // step duration
12 => int NUM_STEPS;  // steps per sequence]
1 => int PLAYING;
0 => int MODE;
3::second => dur TIME;

// modes
2 => int MODES;
0 => int HORIZONTAL;
1 => int VERTICAL;

// Global Canvas Params ====================================================

// Musical constants ====================================================

[60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71] @=> int SCALE[];

// Note constants
0 => int NONE;

// Notes
3 => int C;
4 => int C_SHARP;

5 => int D;
6 => int D_SHARP;

7 => int E;

8 => int F;
9 => int F_SHARP;

10 => int G;
11 => int G_SHARP;

12 => int A;
13 => int A_SHARP;

14 => int B;

15 => int CLEAR;
16 => int SET_ALL;
17 => int CHANGE_MODE;

// Initial selected note
C => int selected;


// Scene setup ================================================================
GG.scene() @=> GScene @ scene;
GG.camera() @=> GCamera @ cam;
cam.orthographic();  // Orthographic camera mode for 2D scene
// GG.fullscreen();
scene.backgroundColor(Color.BLACK);
// update pad positions on window resize
fun void resizeListener() {
    placePads();
    WindowResizeEvent e;  // now listens to the window resize event
    while (true) {
        e => now;  // window has been resized!
        <<< GG.windowWidth(), " , ", GG.windowHeight() >>>;
        placePads();
    }
} spork ~ resizeListener();

// Pad Placement  ==================================================================

GGen pixelGroups[NUM_STEPS];          // one group per column
for (auto group : pixelGroups) group --> GG.scene();

// lead pads
GPad pixelPads[NUM_STEPS][NUM_STEPS];

// place pads based on window size
fun void placePads() {
    // recalculate aspect
    (GG.frameWidth() * 1.0) / (GG.frameHeight() * 1.0) => float aspect;
    // calculate ratio between old and new height/width
    cam.viewSize() => float frustrumHeight;  // height of screen in world-space units
    frustrumHeight * aspect => float frustrumWidth;  // width of the screen in world-space units
    frustrumWidth / NUM_STEPS => float padSpacing;


    for (0 => int i; i < NUM_STEPS; i++) {
        placePadsVertical(
        pixelPads[i], pixelGroups[i],
        frustrumHeight,
        frustrumWidth, i
        );
    }
}

// places along horizontal axis
fun void placePadsHorizontal(GPad pads[], GGen @ parent, float width, float y) {
    width / pads.size() => float padSpacing;
    for (0 => int i; i < pads.size(); i++) {
        pads[i] @=> GPad pad;

        // initialize pad
        pad.init(mouse);

        // connect to scene
        pad --> parent;

        // set transform

        pad.posX(padSpacing * i - width / 2.0 + padSpacing / 2.0);
    }
    parent.posY(y);  // position the entire row
}

// places along vertical axis
fun void placePadsVertical(GPad pads[], GGen @ parent, float height, float width, float idx)
{
    // scale height down a smidge
    // .95 *=> height;
    height / pads.size() => float padSpacing;
    for (0 => int i; i < pads.size(); i++) {
        pads[i] @=> GPad pad;

        // initialize pad
        pad.init(mouse);

        // connect to scene
        pad --> parent;

        // set transform
        pad.sca(padSpacing*0.95);
        pad.posY(padSpacing * i - height / 2.0 + padSpacing / 2.0);
        pad.posX(padSpacing * idx - width / 2.0 + padSpacing / 2.0);
    }
    // parent.posX(x);  // position entire column
}

// Instrumentation ==================================================================

class pixel extends Chugraph {
    inlet => TubeBell voc => JCRev r => ADSR e => outlet;

    fun void play(int note){
        Std.mtof(SCALE[note - 3]) => voc.freq;
        .9 => voc.noteOn;
        e.keyOn();
        TIME => now;
        e.keyOff();
        e.releaseTime() => now;
    }
}

// Sequencer ===================================================================
Gain main => JCRev rev => dac;  // main bus
.1 => main.gain;
0.1 => rev.mix;


// initialize lead instrument
pixel pixels[SCALE.size()];
for (auto p : pixels) {
    p => main;
    p.gain(3.0 / pixels.size());  // reduce gain according to # of voices
}


fun void sequenceLeadHorizontal(pixel leads[], GPad pads[][], dur step) {
    while (true) {
        for (0 => int i; i < pads[0].size(); i++) {
            pads[i] @=> GPad col[];
            // play all active pads in column

            for (0 => int j; j < pads.size(); j++) {
                if (col[j].active() && MODE == HORIZONTAL && PLAYING) {
                    col[j].play(true);

                    spork ~ leads[j].play(col[j].getState());
                }
            }
            // pass time
            step => now;
            // stop all animations
            for (0 => int j; j < pads.size(); j++) {
                col[j].stop();
            }
        }
    }
} spork ~ sequenceLeadHorizontal(pixels, pixelPads, STEP/2.0);


fun void sequenceLeadVertical(pixel leads[], GPad pads[][], dur step) {
    while (true) {
        for (0 => int i; i < pads[0].size(); i++) {
            // play all active pads in column

            for (0 => int j; j < pads.size(); j++) {

                pads[j][i] @=> GPad pad;
                if (pad.active() && MODE == VERTICAL && PLAYING) {
                    pad.play(true);

                    spork ~ leads[i].play(pad.getState());
                }
            }
            // pass time
            step => now;
            // stop all animations
            for (0 => int j; j < pads.size(); j++) {
                pads[j][i] @=> GPad pad;
                pad.stop();
            }
        }
    }
} spork ~ sequenceLeadVertical(pixels, pixelPads, STEP / 2.0);


// Canvas algos ===================================================================

fun void clear(){
    setAll(NONE);
}

fun void setAll(int note){
    for (int i; i < NUM_STEPS; i++) {
        for (int j; j < NUM_STEPS; j++){
            pixelPads[i][j].setState(note);
        }
    }
}

fun void setSelected(int note){
    note => selected;

    // set basic pads
    for (int i; i < NUM_STEPS; i++) {
        for (int j; j < NUM_STEPS; j++){
            pixelPads[i][j].setSelected(selected);
        }
    }
}


[
    KB.KEY_1, C,
    KB.KEY_2, C_SHARP,
    KB.KEY_3, D,
    KB.KEY_4, D_SHARP,
    KB.KEY_5, E,
    KB.KEY_6, F,
    KB.KEY_7, F_SHARP,
    KB.KEY_8, G,
    KB.KEY_9, G_SHARP,
    KB.KEY_0, A,
    KB.KEY_MINUS, A_SHARP,
    KB.KEY_EQUAL, B,
    KB.KEY_E, NONE,
    KB.KEY_R, CLEAR,
    KB.KEY_A, SET_ALL,
    KB.KEY_M, CHANGE_MODE
] @=> int keyNoteMap[];

fun void handleKeyboard(){
    for (0 => int i; i < keyNoteMap.size(); 2 + i =>i) {
        if (KB.isKeyDown(keyNoteMap[i])) {
            keyNoteMap[i + 1] @=> int  command;
            if (command == CLEAR){
                clear();
                break;
            } else if (command == SET_ALL){
                setAll(selected);
                break;
            } else if (command == CHANGE_MODE){
                1 +=> MODE;
                MODE % MODES => MODE;  
            } else {
                setSelected(selected);
            }
        }
    }
    

    if (KB.isKeyDown(KB.KEY_SPACE)){
        if (PLAYING){
            0 => PLAYING;
            <<< "paused" >>>;
        } else {
            1 => PLAYING;
            <<< "playing" >>>;
        }
    }


    16::ms => now;
}

// Game loop ==================================================================
while (true) { 
    GG.nextFrame() => now; 
    handleKeyboard();
}

