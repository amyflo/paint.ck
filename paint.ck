// Initialize Mouse Manager ===================================================
Mouse mouse;
spork ~ mouse.start(0);  // start listening for mouse events
spork ~ mouse.selfUpdate(); // start updating mouse position


// Global Sequencer Params ====================================================

60 => int BPM;  // beats per minute
(1.0/BPM)::minute / 2.0 => dur STEP;  // step duration
16 => int NUM_STEPS;  // steps per sequence]
20 => int ROWS;


0 => int PLAYING;

[60, 61, 62, 63, 64, 65, 66, 67, 68, 69, 70, 71] @=> int SCALE[];  

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

C => int selected;

// Scene setup ================================================================
GG.scene() @=> GScene @ scene;
GG.camera() @=> GCamera @ cam;
cam.orthographic();  // Orthographic camera mode for 2D scene

GGen canvas;
GGen BitBassGroups[NUM_STEPS];          // one group per column
for (auto group : BitBassGroups) group --> canvas;
canvas.sca(0.65);
canvas.translateY(-0.5);
canvas --> GG.scene();
scene.backgroundColor(Color.BLACK);

GPlane menu; 
menu --> GG.scene();
menu.scaX(100);
menu.scaY(1);
menu.posZ(-4);
menu.translateY(-3.1);

// lead pads
GPad BitBassPads[NUM_STEPS][ROWS];

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


16 => int numButtons;
Button notes[numButtons];
GGen noteGroup;
noteGroup --> GG.scene();

fun void placeNotes(Button notes[], GGen @ parent, float width, float height){

    // .95 *=> height;
    width / notes.size() => float noteSpacing;
    for (0 => int i; i < notes.size(); i++) {
        notes[i] @=> Button note;

        // initialize pad
        
        if (i > 12){
            note.init(mouse, i, 1);
        } else {
            note.init(mouse, i, 0);
        }
       

        // connect to scene
        note --> parent;

        // set transform
        note.sca(noteSpacing * .95);
        note.posX(noteSpacing * i - width / 2.0 + noteSpacing / 2.0);
        note.posY(noteSpacing * 0 - height / 2.0 + noteSpacing / 2.0);
    }
}

// place pads based on window size
fun void placePads() {
    // recalculate aspect
    (GG.frameWidth() * 1.0) / (GG.frameHeight() * 1.0) => float aspect;
    // calculate ratio between old and new height/width
    cam.viewSize() => float frustrumHeight;  // height of screen in world-space units
    frustrumHeight * aspect => float frustrumWidth;  // widht of the screen in world-space units
    frustrumWidth / NUM_STEPS => float padSpacing;

    placeNotes(notes, noteGroup, frustrumWidth, frustrumHeight);

    for (0 => int i; i < NUM_STEPS; i++) {
        placePadsHorizontal(
        BitBassPads[i], BitBassGroups[i],
        frustrumWidth, frustrumHeight - padSpacing, i
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

class BitBass extends Chugraph {
    PulseOsc saw1, saw2;
    ADSR env;                                      // amplitude EG
    Step step => Envelope filterEnv => blackhole;  // filter cutoff EG
    LPF filter;

    PulseOsc freqLFO => blackhole;  // LFO to modulate filter frequency
    PulseOsc qLFO => blackhole;     // LFO to modulate filter resonance
    saw1 => env => filter => Gain g => outlet;
    saw2 => env => filter => g => outlet;

    // initialize amp EG
    env.set(20::ms, 30::ms, .9, 100::ms);

    // initialize filter EG
    step.next(3.0);
    filterEnv.duration(100::ms);

    // initialize filter LFOs
    freqLFO.period(8::second);
    qLFO.period(10::second);

    // initialize filter
    filter.freq(100);
    filter.Q(100);

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
BitBass BitBasses[ROWS];
for (auto bass : BitBasses) {
    bass => main;
    bass.gain(3.0 / BitBasses.size());  // reduce gain according to # of voices
}

fun void setAll(int note){
    note => selected;

    // set basic pads
    for (int i; i < NUM_STEPS; i++) {
        for (int j; j < ROWS; j++){
            BitBassPads[i][j].setState(selected);
        }
    }
}


fun void setSelected(int note){
    note => selected;


    if (selected ==  NONE){
        resetNotes(12);
        
    } else {
            resetNotes(selected  - 3);
    }
    
    for (int i; i < NUM_STEPS; i++) {
        for (int j; j < ROWS; j++){
            BitBassPads[i][j].setSelected(selected);
        }
    }
}

spork ~ sequenceLead(BitBasses, BitBassPads, SCALE, 60 - 2 * 12, STEP / 2.0);

// sequence percussion (monophonic)
fun void sequenceBeat(Instrument @ instrument, GPad pads[], int rev, dur step) {
    0 => int i;
    if (rev) pads.size() - 1 => i;
    while (true) {
        false => int juice;
        if (pads[i].active() && PLAYING) {
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
fun void sequenceLead(BitBass leads[], GPad pads[][], int scale[], int root, dur step) {
    while (true) {
        for (0 => int i; i < pads.size(); i++) {
            pads[i] @=> GPad col[];
            // play all active pads in column

            for (0 => int j; j < col.size(); j++) {
                if (col[j].active()  && PLAYING) {
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
    if (KB.isKeyDown(KB.KEY_EQUAL)){
        setSelected(B);
    }
    if (KB.isKeyDown(KB.KEY_BACKSPACE)){
        setSelected(NONE);
    }

    if (KB.isKeyDown(KB.KEY_R)){
        setAll(NONE);
        notes[13].turnOff();
    }
    if (KB.isKeyDown(KB.KEY_F)){
        setAll(selected);
        notes[14].turnOff();
    }

    if (KB.isKeyDown(KB.KEY_A)){
        
        if (selected == NONE){
            setSelected(B);
            200::ms => now;
        } else if (selected == C) {
            setSelected(NONE);
            200::ms => now;
        }else {
            setSelected(selected -  1);
            200::ms => now;
        }
    }

    if (KB.isKeyDown(KB.KEY_D)){
        
        if (selected == NONE){
            setSelected(C);
            200::ms => now;
        } else if (selected == B) {
            setSelected(NONE);
            200::ms => now;
        }else {
            setSelected(selected +  1);
            200::ms => now;
        }
    }
    16::ms => now;
}

fun void resetNotes(int exception){
    for (0 => int i; i < 13; i++){
        notes[i].turnOff();
    }
    notes[exception].turnOn();
}

fun void handleControls(){
    //  RESET
    if (notes[13].on()){
        setAll(NONE);
        notes[13].turnOff();
    }
    
    // FILL
    if (notes[14].on()){
        setAll(selected);
        notes[14].turnOff();
    }

    if (notes[15].on()){
        1 => PLAYING;
    } else {
        0 => PLAYING;
    }
}



setSelected(C);

// Game loop ==================================================================
while (true) { 
    GG.nextFrame() => now; 
    handleControls();
    handleKeyboard();
}
