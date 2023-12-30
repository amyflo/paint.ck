public class Palette extends GGen {

    13 => int SIZE;
    [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14]  @=> int note_consts[];

   [
        Color.WHITE,    // NONE

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

    GGen noteGroup --> GG.scene();
    Note notes[SIZE];

    for (0 => int i; i < SIZE; i++) {
        notes[i].init(mouse,note_consts[i], colorMap[i], colorMap[i]);
    }

    

    
    


    pad.init(mouse);