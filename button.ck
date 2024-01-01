public class Button extends GGen {
    // initialize mesh
    GPlane pad --> this;

    0 => static int OFF;
    1 => static int ON;

    FlatMaterial mat;
    pad.mat(mat);

    // input types
    0 => static int MOUSE_HOVER;
    1 => static int MOUSE_EXIT;
    2 => static int MOUSE_CLICK;


    [
        Color.LIGHTGRAY,      // HOVERED
        Color.BLACK,     // PLAYING
    ] @=> vec3 colorMap[];

    0 => int state; // current state


    Mouse @ mouse;

    // events
    Event onClickEvent;

    fun void init(Mouse @ m) {
        if (mouse != null) return;
        m @=> this.mouse;
        spork ~ this.clickListener();
    }


    0 => int lastState;
    // enter state, remember last state
    fun void enter(int s) {
        state => lastState;
        s => state;
    }

    fun int on(){
        return state == ON;
    }

    fun void turnOn(){
        enter(ON);
    }

    fun void turnOff(){
        enter(OFF);
    }

    fun void toggle(){
        if (on()){
            turnOff();
        } else {
            turnOn();
        }
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


    // set color
    fun void color(vec3 c) {
        pad.mat().color(c);
    }
    // handle mouse clicks
    fun void clickListener() {
        now => time lastClick;
        while (true) {
           
            mouse.mouseDownEvents[Mouse.LEFT_CLICK] => now;

            if (isHovered()) {
                onClickEvent.broadcast();
                toggle();
            }
            100::ms => now; // cooldown
        }
    }

    // override ggen update
    fun void update(float dt) {
        // check if hovered

        // update state
        this.color(colorMap[state]);
    }
}