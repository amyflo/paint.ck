
<img width="1440" alt="Screenshot 2024-01-01 at 7 23 17 PM" src="https://github.com/amyflo/paint.ck/assets/60983630/90774143-e0da-41e6-8692-e2da982d471a">

# paint.ck
paint.ck is a pixel art drawing beat sequencer built using ChucK and ChuGL. Each note on the 12-note chromatic scale is represented by a unique color, in roughly rainbow order. The tool is fully functional both as a musical and drawing application. Created for CS476A Fall 2023 at Stanford University. 

[Watch the demo on YouTube](https://youtu.be/UwEDb3IMif4?si=IBGKEFWVAo3n4qph) | [Learn more about this project on Medium](https://amyflo.medium.com/groove-n-bloom-cs476a-hw-3-beat-sequencer-d80f617fa5ed)

## Instructions.

### To run
-  [Install Chuck and ChuGL's latest release](https://chuck.stanford.edu/chugl/)
-  Run `chuck go.ck`
-  Try clicking and dragging on the canvas to draw!

### Controls
#### Mouse Controls
##### User Interface (Rightmost three buttons only)
- reset: erases all pixels on the grid
- fill: fills grid with selected color
- play/pause: stops the beat sequencer
##### Canvas
- on hover on the canvas: Preview the currently selected note of a pixel.
- on click or on drag on the canvas: Change the note of a pixel.

#### Keyboard Controls
- 1 to - represents the 12-note chromatic musical scale from C to Bb. For example, “C#” would be selected by 2 on the keyboard, and “B” would be selected by -on the keyboard.
backspace selects the erase tool.
- r resets the canvas to the default grid.
- f fills the canvas with the selected color
- d (left) and a (right) can be pressed to quickly move through the note inventory.

