// Initialize Mouse Manager ===================================================
Mouse mouse;
spork ~ mouse.start(0);  // start listening for mouse events
spork ~ mouse.selfUpdate(); // start updating mouse position


// Global Sequencer Params ====================================================

120 => int BPM;  // beats per minute
(1.0/BPM)::minute / 2.0 => dur STEP;  // step duration
20 => int NUM_STEPS;  // steps per sequence]
24 => int ROWS;

1 => int PLAYING;

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

GGen kickPadGroup --> GG.scene();        // bottom row
GGen snarePadGroup --> GG.scene();       // top row
GGen openHatPadGroup --> GG.scene();     // left column
GGen closedHatPadGroup --> GG.scene();   // right column

GGen acidBassGroups[NUM_STEPS];          // one group per column
for (auto group : acidBassGroups) group --> GG.scene();

// lead pads
GPad acidBassPads[NUM_STEPS][ROWS];

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
    frustrumHeight * aspect => float frustrumWidth;  // widht of the screen in world-space units
    frustrumWidth / NUM_STEPS => float padSpacing;


    for (0 => int i; i < NUM_STEPS; i++) {
        placePadsHorizontal(
        acidBassPads[i], acidBassGroups[i],
        frustrumWidth, frustrumHeight, i
        );
    }
}

// places along horizontal axis
fun void placePadsHorizontal(GPad pads[], GGen @ parent, float width, float height, float idx) {
    
    // .95 *=> height;
    width / pads.size() => float padSpacing;
    for (0 => int i; i < pads.size(); i++) {
        pads[i] @=> GPad pad;

        // initialize pad
        pad.init(mouse);

        // connect to scene
        pad --> parent;

        // set transform
        pad.sca(padSpacing * .95);
        pad.posX(padSpacing * i - width / 2.0 + padSpacing / 2.0);
        pad.posY(padSpacing * idx - height / 2.0 + padSpacing / 2.0);
    }
   // parent.posY(y);  // position the entire row
}

// Instruments ==================================================================

class AcidBass extends Chugraph {
    SawOsc saw1, saw2;
    ADSR env;                                      // amplitude EG
    Step step => Envelope filterEnv => blackhole;  // filter cutoff EG
    LPF filter;

    TriOsc freqLFO => blackhole;  // LFO to modulate filter frequency
    TriOsc qLFO => blackhole;     // LFO to modulate filter resonance
    saw1 => env => filter => Gain g => outlet;
    saw2 => env => filter;

    // initialize amp EG
    env.set(40::ms, 10::ms, .6, 150::ms);

    // initialize filter EG
    step.next(1.0);
    filterEnv.duration(50::ms);

    // initialize filter LFOs
    freqLFO.period(8::second);
    qLFO.period(10::second);

    // initialize filter
    filter.freq(1500);
    filter.Q(10);

    fun void modulate() {
        while (true) {
            // remap [-1, 1] --> [100, 2600]
            Math.map(freqLFO.last(), -1.0, 1.0, 100, 12000) => float filterFreq;
            // remap [-1, 1] --> [1, 10]
            Math.map(qLFO.last(), -1.0, 1.0, .1, 8) => filter.Q;
             
            // apply filter EG
            filterEnv.last() * filterFreq + 100 => filter.freq;

            1::ms => now;
        }
    } spork ~ modulate();

    // spork to play!
    fun void play(int note) {

        Std.mtof(SCALE[note - 3]) => float freq;

        // set frequencies
        saw1.freq(freq);
        saw2.freq(2 * freq * 1.01); // slight detune for more harmonic content
    

        // activate EGs
        env.keyOn(); filterEnv.keyOn();
        // wait for note to hit sustain portion of ADSR
        env.attackTime() + env.decayTime() => now;
        // deactivate EGs
        env.keyOff(); filterEnv.keyOff();
        // wait for note to finish
        env.releaseTime() => now;
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
AcidBass acidBasses[ROWS];
for (auto bass : acidBasses) {
    bass => main;
    bass.gain(3.0 / acidBasses.size());  // reduce gain according to # of voices
}

fun void setAll(int note){
    note => selected;

    // set basic pads
    for (int i; i < NUM_STEPS; i++) {
        for (int j; j < ROWS; j++){
            acidBassPads[i][j].setState(selected);
        }
    }
}


fun void setSelected(int note){
    note => selected;

    // set basic pads
    for (int i; i < NUM_STEPS; i++) {
        for (int j; j < ROWS; j++){
            acidBassPads[i][j].setSelected(selected);
        }
    }
}

spork ~ sequenceLead(acidBasses, acidBassPads, SCALE, 60 - 2 * 12, STEP / 2.0);

// sequence percussion (monophonic)
fun void sequenceBeat(Instrument @ instrument, GPad pads[], int rev, dur step) {
    0 => int i;
    if (rev) pads.size() - 1 => i;
    while (PLAYING) {
        false => int juice;
        if (pads[i].active()) {
            true => juice;
            spork ~ instrument.play();  // play sound
        }
        // start animation
        pads[i].play(juice);  // must happen after .active() check
        // pass time
        step => now;
        // stop animation
        pads[i].stop();

        // bump index, wrap around playhead to other end
        if (rev) {
            i--;
            if (i < 0) pads.size() - 1 => i;
        } else {
            i++;
            if (i >= pads.size()) 0 => i;
        }
    }
} 

// sequence lead (polyphonic)
fun void sequenceLead(AcidBass leads[], GPad pads[][], int scale[], int root, dur step) {
    while (true) {
        for (0 => int i; i < pads.size(); i++) {
            pads[i] @=> GPad col[];
            // play all active pads in column

            for (0 => int j; j < col.size(); j++) {
                if (col[j].active()) {
                    col[j].play(true);

                    // TODO: play the note based on the color
                    spork ~ leads[j].play(col[j].getState());
                }
            }
            // pass time
            step => now;
            // stop all animations
            for (0 => int j; j < col.size(); j++) {
                col[j].stop();
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

    // fill
    if (KB.isKeyDown(KB.KEY_F)){
        setAll(selected);
    }
    // reset
    if (KB.isKeyDown(KB.KEY_R)){
        setAll(NONE);
    }
    16::ms => now;
}

// Game loop ==================================================================
while (true) { 
    GG.nextFrame() => now; 
    handleKeyboard();
}
