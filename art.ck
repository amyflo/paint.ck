// Initialize Mouse Manager ===================================================
Mouse mouse;
spork ~ mouse.start(0);  // start listening for mouse events
spork ~ mouse.selfUpdate(); // start updating mouse position


// Global Sequencer Params ====================================================

120 => int BPM;  // beats per minute
(1.0/BPM)::minute / 2.0 => dur STEP;  // step duration
16 => int NUM_STEPS;  // steps per sequence]

1 => int  PLAYING;

[
    -5, -2, 0, 3, 5, 7, 10, 12, 15
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
GPad acidBassPads[NUM_STEPS][SCALE.size()];
// percussion pads
GPad kickPads[NUM_STEPS];
GPad snarePads[NUM_STEPS];
GPad openHatPads[NUM_STEPS];
GPad closedHatPads[NUM_STEPS];

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
        pad.sca(padSpacing * .7);
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
        // pad.sca(padSpacing * .7);
        pad.sca(0.8);
        pad.posY(padSpacing * i - height / 2.0 + padSpacing / 2.0);
        pad.posX(padSpacing * idx - width / 2.0 + padSpacing / 2.0);
    }
    // parent.posX(x);  // position entire column
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
        Std.mtof(note) => float freq;

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

// Synthesized percussion instruments are borrowed (stolen!)
// from Tristan Peng's HW1: https://ccrma.stanford.edu/~pengt/256a/hw1.html

// thanks Tristan
class Kick extends Instrument { 
    inlet => Noise n => LPF f => ADSR e => outlet;
    110 => f.freq;
    40 => f.gain;
    e.set(5::ms, 50::ms, 0.1, 100::ms);

    fun void play() {
        e.keyOn();
        50::ms => now;
        e.keyOff();
        e.releaseTime() => now;
    }
}

// thanks Tristan
class Snare extends Instrument {  
    inlet => Noise n => BPF f => ADSR e => outlet;
    440 => f.freq;
    15. => f.Q;
    15 => f.gain;
    e.set(5::ms, 50::ms, 0.1, 50::ms);

    fun void play() {
        e.keyOn();
        50::ms => now;
        e.keyOff();
        e.releaseTime() => now;
    }

}

// thanks Tristan
class Hat extends Instrument {
    inlet => Noise n => HPF f => ADSR e => outlet;
    2500 => f.freq;
    0.05 => f.gain;
    e.set(5::ms, 50::ms, 0.1, 100::ms);

    fun void play() {
        e.keyOn();
        50::ms => now;
        e.keyOff();
        e.releaseTime() => now;
    }
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

// initialize percussion instruments
Kick kick => main;
Snare snare => main;
Hat openHat => main;
Hat closedHat => main;


fun void setSelected(int note){
    note => selected;

    // set basic pads
    for (int i; i < NUM_STEPS; i++) {
        kickPads[i].setSelected(selected);
        snarePads[i].setSelected(selected);
        openHatPads[i].setSelected(selected);
        closedHatPads[i].setSelected(selected);
        for (int j; j < SCALE.size(); j++){
            acidBassPads[i][j].setSelected(selected);
        }
    }
}



// sequence instruments!
spork ~ sequenceBeat(kick, kickPads, true, STEP);
spork ~ sequenceBeat(snare, snarePads, false, STEP / 2.0);
spork ~ sequenceBeat(openHat, openHatPads, false, STEP / 2.0);
spork ~ sequenceBeat(closedHat, closedHatPads, true, STEP / 2.0);
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
                    spork ~ leads[j].play(root + scale[j]);
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


// // KBManager usage
// KBManager IM;
// spork ~ IM.start(0);

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
    16::ms => now;
}

// Game loop ==================================================================
while (true) { 
    GG.nextFrame() => now; 
    handleKeyboard();
}

