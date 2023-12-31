// Initialize Mouse Manager ===================================================
Mouse mouse;
spork ~ mouse.start(0);  // start listening for mouse events
spork ~ mouse.selfUpdate(); // start updating mouse position


// Global Sequencer Params ====================================================

30 => int BPM;  // beats per minute
(1.0/BPM)::minute / 2.0 => dur STEP;  // step duration
8 => int NUM_STEPS;  // steps per sequence]
1 => int PLAYING;
0 => int MODE;

0 => int HORIZONTAL;
1 => int VERTICAL;
3::second => dur TIME;


[
60,
61,
62,
63,
64,
65,
66,
67,
68,
69,
70,
71
] @=> int SCALE[];  // relative MIDI offsets for minor pentatonic scale


0 =>  int NONE;
// notes
3 =>  int C;
4 =>  int C_SHARP;

5 =>  int D;
6 =>  int D_SHARP;

7 =>  int E;

8 =>  int F;
9 =>  int F_SHARP;

10 =>  int G;
11 =>  int G_SHARP;

12 =>  int A;
13 =>  int A_SHARP;

14 =>  int B;

D_SHARP => int selected;

// Scene setup ================================================================
GG.scene() @=> GScene @ scene;
GG.camera() @=> GCamera @ cam;
cam.orthographic();  // Orthographic camera mode for 2D scene
// GG.fullscreen();
scene.backgroundColor(Color.DARKGRAY);

GGen kickPadGroup --> GG.scene();        // bottom row
GGen snarePadGroup --> GG.scene();       // top row
GGen openHatPadGroup --> GG.scene();     // left column
GGen closedHatPadGroup --> GG.scene();   // right column

GGen acidBassGroups[NUM_STEPS];          // one group per column
for (auto group : acidBassGroups) group --> GG.scene();

// lead pads
GPad acidBassPads[NUM_STEPS * 2][NUM_STEPS];

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
        acidBassPads[i], acidBassGroups[i],
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

// Instruments ==================================================================

class AcidBass extends Chugraph {
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

// base class for percussion instruments
class Instrument extends Chugraph {
    fun void play() {}
}

// Sequencer ===================================================================
Gain main => JCRev rev => dac;  // main bus
.1 => main.gain;
0.1 => rev.mix;

// initialzie lead instrument
AcidBass acidBasses[SCALE.size()];
for (auto bass : acidBasses) {
    bass => main;
    bass.gain(3.0 / acidBasses.size());  // reduce gain according to # of voices
}



fun void clear(){
    setAll(NONE);
}

fun void setAll(int note){
    for (int i; i < NUM_STEPS; i++) {
        for (int j; j < NUM_STEPS; j++){
            acidBassPads[i][j].setState(note);
        }
    }
}

fun void setSelected(int note){
    note => selected;

    // set basic pads
    for (int i; i < NUM_STEPS; i++) {
        for (int j; j < NUM_STEPS; j++){
            acidBassPads[i][j].setSelected(selected);
        }
    }
}


fun void sequenceLeadHorizontal(AcidBass leads[], GPad pads[][], int scale[], int root, dur step) {
    while (true) {
        for (0 => int i; i < NUM_STEPS; i++) {
            pads[i] @=> GPad col[];
            // play all active pads in column

            for (0 => int j; j < NUM_STEPS; j++) {
                if (col[j].active() && MODE == HORIZONTAL && PLAYING) {
                    col[j].play(true);

                    spork ~ leads[j].play(col[j].getState());
                }
            }
            // pass time
            step => now;
            // stop all animations
            for (0 => int j; j < NUM_STEPS; j++) {
                col[j].stop();
            }
        }
    }
}

spork ~ sequenceLeadHorizontal(acidBasses, acidBassPads, SCALE, 60 - 2 * 12, STEP / 2.0);
spork ~ sequenceLeadVertical(acidBasses, acidBassPads, SCALE, 60 - 2 * 12, STEP / 2.0);


fun void sequenceLeadVertical(AcidBass leads[], GPad pads[][], int scale[], int root, dur step) {
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
}



fun void handleKeyboard(){
    if (KB.isKeyDown(KB.KEY_1)){
        setSelected(C);
    }

    if (KB.isKeyDown(KB.KEY_2)){
        setSelected(C_SHARP);
    }

    if (KB.isKeyDown(KB.KEY_3)){
        setSelected(D);
    }

    if (KB.isKeyDown(KB.KEY_4)){
        setSelected(D_SHARP);
    }

    if (KB.isKeyDown(KB.KEY_5)){
        setSelected(E);
    }

    if (KB.isKeyDown(KB.KEY_6)){
        setSelected(F);
    }
    if (KB.isKeyDown(KB.KEY_7)){
        setSelected(F_SHARP);
    }
    if (KB.isKeyDown(KB.KEY_8)){
        setSelected(G);
    }
    if (KB.isKeyDown(KB.KEY_9)){
        setSelected(G_SHARP);
    }
    if (KB.isKeyDown(KB.KEY_0)){
        setSelected(A);
    }
    if (KB.isKeyDown(KB.KEY_MINUS)){
        setSelected(A_SHARP);
    }
    if (KB.isKeyDown(KB.KEY_MINUS)){
        setSelected(B);
    }
    if (KB.isKeyDown(KB.KEY_E)){
        setSelected(NONE);
    }
    if (KB.isKeyDown(KB.KEY_R)){
        clear();
    }
    if (KB.isKeyDown(KB.KEY_A)){
        setAll(selected);
    }

    if (KB.isKeyDown(KB.KEY_P)){
        if (PLAYING){
            0 => PLAYING;
            <<< "paused" >>>;
        } else {
            1 => PLAYING;
            <<< "playing" >>>;
        }
    }

     if (KB.isKeyDown(KB.KEY_M)){
        1 +=> MODE;
        MODE % 2 => MODE;  
        <<< MODE >>>;      
    }

    16::ms => now;
}

// Game loop ==================================================================
while (true) { 
    GG.nextFrame() => now; 
    handleKeyboard();
}

