public class Note extends GGen {
    // initialize mesh
    GPlane pad --> this;
    FlatMaterial mat;
    pad.mat(mat);
    
    0 => static int NONE;
    1 => static int HOVERED;
    2 => static int ACTIVE;

    [
        Color.WHITE,    // NONE
        Color.GRAY,      // HOVERED
        Color.BLACK,     // ACTIVE
    ] @=> vec3 colorMap[];

    // input types
    0 => static int MOUSE_HOVER;
    1 => static int MOUSE_EXIT;
    2 => static int MOUSE_CLICK;

    0 => int state; // current state

    0 => int NOTE;

    // reference to a mouse
    Mouse @ mouse;

    // events
    Event onHoverEvent, onClickEvent;

    fun void init(Mouse @ m, int note, vec3 color, vec3 hover) {
        if (mouse != null) return;
        m @=> this.mouse;
        spork ~ this.clickListener();
        note => NOTE;

    }


    // check if state is active (i.e. should play sound)
    fun int active() {
        return state == ACTIVE;
    }

  
    fun int getState() {
        return state;
    }

    fun int hover(){
        return state == HOVERED;
    }

    fun void  border
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



    0 => int lastState;
    // enter state, remember last state
    fun void enter(int s) {
        state => lastState;
        s => state;

        // set color when playing to the last state
        if (state > PLAYING) colorMap[lastState] => colorMap[PLAYING];
    }

    // basic state machine for handling input
    fun void handleInput(int input) {

        if (state == NONE) {
            if (input == MOUSE_HOVER)      enter(HOVERED);
            else if (input == MOUSE_CLICK) enter(ACTIVE);
        } else if (state == HOVERED) {
            if (input == MOUSE_EXIT)       enter(NONE);
            else if (input == MOUSE_CLICK) enter(ACTIVE);
        } else if (state == ACTIVE) {
            
            if (input == MOUSE_HOVER)      enter(HOVERED);
            if (input == MOUSE_CLICK)      enter(NONE);
        }
    }

    // override ggen update
    fun void update(float dt) {
        // check if hovered
        pollHover();

        // update state
        this.color(colorMap[state]);

        if (state ==  ACTIVE) {
            pad.sca(1.5);
        }
    }
}