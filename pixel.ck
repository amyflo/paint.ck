public class GPad extends GGen {
    // initialize mesh
    GPlane pad --> this;
    FlatMaterial mat;
    pad.mat(mat);
    
    0 => static int NONE;
    1 => static int HOVERED;
    2 => static int PLAYING;

    // notes
    3 => static int C;
    4 => static int C_SHARP;

    5 => static int D;
    6 => static int D_SHARP;

    7 => static int E;

    8 => static int F;
    9 => static int F_SHARP;

    10 => static int G;
    11 => static int G_SHARP;

    12 => static int A;
    13 => static int A_SHARP;

    14 => static int B;

    [
        Color.WHITE,    // NONE
        Color.GRAY,      // HOVERED
        Color.BLACK,     // PLAYING

        // ACTIVE
        Color.RED, // C
        Color.ORANGE, // C#
        Color.YELLOW, // D
        Color.GREEN, // D#
        Color.DARKGREEN,// E
        Color.BLUE,// F
        Color.DARKBLUE,// F#
        Color.MAGENTA, // G
        Color.VIOLET, // G#
        Color.PINK,// A
        Color.MAROON,// A#
        Color.BROWN // B
    ] @=> vec3 colorMap[];

    // input types
    0 => static int MOUSE_HOVER;
    1 => static int MOUSE_EXIT;
    2 => static int MOUSE_CLICK;
    3 => static int NOTE_ON;
    4 => static int NOTE_OFF;

    0 => int state; // current state
    NONE => int selected;

    // reference to a mouse
    Mouse @ mouse;

    // events
    Event onHoverEvent, onClickEvent;

    fun void init(Mouse @ m) {
        if (mouse != null) return;
        m @=> this.mouse;
        spork ~ this.clickListener();
    }

    // check if state is active (i.e. should play sound)
    fun int active() {
        return !(state == NONE || state == HOVERED);
    }

    fun int getSelected(){
        return selected;
    }

    fun void setSelected(int note){
        note => selected;
    }

    fun void setState(int note) {
        note => state;
    }

    fun int getState() {
        return state;
    }

    fun int hover(){
        return state == HOVERED;
    }

    // set color
    fun void color(vec3 c) {
        pad.mat().color(c);
    }

    // returns true if mouse is hovering over pad
    fun int isHovered() {
        pad.scaWorld() => vec3 worldScale;  // get dimensions
        worldScale.x / 2.0 => float halfWidth;
        worldScale.y / 2.0 => float halfHeight;
        pad.posWorld() => vec3 worldPos;   // get position

        if (mouse.worldPos.x > worldPos.x - halfWidth && mouse.worldPos.x < worldPos.x + halfWidth &&
            mouse.worldPos.y > worldPos.y - halfHeight && mouse.worldPos.y < worldPos.y + halfHeight) {
            return true;
        }
        return false;
    }

    // poll for hover events
    fun void pollHover() {
        if (isHovered()) {
            onHoverEvent.broadcast();
            handleInput(MOUSE_HOVER);
        } else {
            if (hover()) handleInput(MOUSE_EXIT);
        }
    }

    // handle mouse clicks
    fun void clickListener() {
        now => time lastClick;
        while (true) {
            mouse.mouseDownEvents[Mouse.LEFT_CLICK] => now;
            if (isHovered()) {
                onClickEvent.broadcast();
                handleInput(MOUSE_CLICK);
            }
            100::ms => now; // cooldown
        }
    }

    fun void play(int juice) {
        if (juice) {
            animate_in();
        }
    }

    fun void animate_in(){
        pad.sca(0.5);
    }

    fun void animate_out(){
        pad.scaX()  + .05 * (1 - pad.scaX()) => pad.sca;
    }

    // stop play animation (called by sequencer on note off)
    fun void stop() {
        handleInput(NOTE_OFF);
    }


    // activate pad, meaning it should be played when the sequencer hits it
    fun void activate() {
        enter(selected);
    }

    0 => int lastState;
    // enter state, remember last state
    fun void enter(int s) {
        state => lastState;
        s => state;
        // set color when playing to the last state
        // if (state > PLAYING) colorMap[lastState] => colorMap[PLAYING];
    }

    // basic state machine for handling input
    fun void handleInput(int input) {
        
        if (input == NOTE_ON) {
            enter(PLAYING);
            return;
        }


        if (state == NONE) {
            if (input == MOUSE_HOVER)      enter(HOVERED);
            else if (input == MOUSE_CLICK) enter(selected);
        } else if (state == HOVERED) {
            if (input == MOUSE_EXIT)       enter(lastState);
            else if (input == MOUSE_CLICK) enter(selected);
        } else if (state == PLAYING) {
            if (input == MOUSE_CLICK)      enter(selected);
            if (input == NOTE_OFF)         enter(lastState);
        } else {
            if (input == MOUSE_CLICK)      enter(selected);
        }

    }

    // override ggen update
    fun void update(float dt) {
        // check if hovered
        pollHover();

        // update state
        this.color(colorMap[state]);

        // interpolate back towards uniform scale (handles animation)

        // this is cursed
        // pad.scaX()  - .03 * Math.pow(Math.fabs((1.0 - pad.scaX())), .3) => pad.sca;
        
        // much less cursed
        animate_out();
    }
}