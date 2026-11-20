# Deck launch film: SPEC

Storyline A, "Next" (see STORYLINES.md). The film is a presentation; every slide change is caused by a real Deck input shown on screen.

```text
GOAL:    The viewer thinks "my iPhone and Watch already are the remote" and looks for Deck.
OUTPUT:  HyperFrames, 1920 x 1080, 30 fps
TIME:    30 s x 30 = 900 frames. Grid 120 BPM = 15 frames a beat, 60 a bar; every input lands on a beat
         so a 120 BPM bed can be dropped in later.
LOOK:    Three flat slide grounds, no gradients: blue #2D6EEF (the logo's deep blue), ink #05070D
         (store previews), paper #F6FBFF (site). Ink on blue and ink grounds is #FFFFFF; on paper #05070D.
         Accent is the blue: one struck line, the reveal flood, the claim, the end card.
         Display: SF Pro Rounded Bold (the app's own headline face), 150-380 px, -2% tracking.
         Sub lines: SF Pro Rounded Medium 44-56 px. Command line: JetBrains Mono 500, 40 px.
         Medium: product UI. The iPhone and Watch screens are rebuilt from the branch's SwiftUI
         (ArcRemoteView.swift, WatchApp/ContentView.swift) with the exact ArcLayout geometry,
         real SF Symbols and the app's colours, checked against simulator captures of this build.
         Device bodies: #0B0B0D, 1 px #2E3036 edge, shadow 0 30 px 80 px at 45%.
OBJECTS: iPhone: tall rounded slab, the arc of round glass buttons with one big white Next button,
         thin rounded timer digits, a hairline arc with minute ticks and a white head.
         Watch: squarer rounded body with a crown on the right, navy round Next button, mono timer.
         Slide: the full frame. Spotlight: 65% black over the slide with a 140 px radius hole
         (SpotlightOverlay.swift: dimOpacity 0.65, radius 13% of display height) and the real Mac arrow cursor.
         Footage: public/demo.MP4, 720x1280, shown full height, never upscaled past 1080 tall.
MOTION:  slide push: 0.5 s power3.inOut, both slides travel 1920 px
         device camera: 0.6 s power2.inOut; device morph: out 0.25 s power3.in, in 0.35 s power3.out
         press: scale 0.92 + opacity 0.75 for 0.12 s (ArcPressStyle), release 0.18 s
         titles: per word, opacity + blur 8 px to 0 in 0.14 s, 70 ms apart, then dead still
         timer: digits roll 0.25 s on each second; arc head linear (it is a clock)
SHOTS:
  0-30     hook      Slide A blue "Next slide, please". Phone close (1.86x) on the arc. Timer 00:00 running.
  30       tap       Next pressed -> push -> Slide B paper "Your iPhone is the remote". Click + whoosh.
  90       tap       push -> Slide C ink. "$1000 iPhone" / "$2000 Mac" / "+ $30-$100 clicker?" build
                     by line (frames 102, 117, 135); phone pulls back to home (1.1x). Blue bar strikes line 3 at 165.
  195      tap       the strike bar floods the frame blue -> Slide D "Deck" + "Your presentation remote
                     for iPhone & Apple Watch".
  240      morph     phone becomes the Watch (double-tap layout).
  270      double tap  Next circle pressed twice -> push -> Slide E paper "Double Tap" / "Never touch the screen".
  330      layout    Watch switches to wrist-flick layout.
  345      flick     Watch body flicks, Next lights yellow -> vertical push -> Slide F ink: the real footage,
                     full height, with "Wrist Flick" / "Present from your wrist". Yellow flashes again on each
                     real slide change in the footage.
  450      morph     Watch becomes the phone (close).
  465      tap       push -> Slide G blue "Built-in timer" / "Haptic alerts at custom intervals".
                     Camera punches in on the readout (2.5x): 00:16, 00:17 tick at 190 px.
  540      tap       push -> Slide H paper: "Works with any app that uses arrow keys" + Keynote, PowerPoint,
                     Google Slides, Figma stacked at 132 px.
  570-690  payoff    Pointer held: button turns white and grows 1.15x, other buttons drop to 30%, caption
                     reads "Pointer active". The slide dims 65% around a spotlight that travels down the four names.
  690      release   the spotlight opens into Slide I blue (iris from the cursor): "No dongles, no BS."
  780      tap       the white Next button leaves the phone and becomes the front card of the logo; the
                     cards deal upward; "Deck" wipes in; App Store line and `brew install --cask deck`. Hold 75 frames.
BANNED:  dark void with small floating UI; glow, bloom, particles; mesh or linear full-frame gradients;
         glass cards; three cards in a row; title over a dimmed screenshot; corner labels; docked logo;
         every element fading and sliding up; titles that drift after landing; click rings;
         tilted 3D device mockups; invented UI (no button, label or state that is not in the Swift source);
         a drawn hand or thumb; the name "Clicker" for the product.
QA:      f0 (thumbnail: slide A + phone, timer 00:00) · f45 (B fully in) · f170 (strike) · f215 (Deck) ·
         f255 (watch) · f300 (Double Tap) · f400 (footage + watch yellow) · f500 (readout punch-in, 00:16) ·
         f620 (spotlight on a name, "Pointer active") · f720 (claim) · f870 (end card).
         Timer digits must equal floor(t) wherever the phone is visible.
```

## Sources for every line of copy

- "Your presentation remote for iPhone & Apple Watch", "Present from your wrist", "Built-in timer", "Never touch the screen": `assets/store-preview-images/`.
- "$1000 iPhone", "$2000 Mac", "$30-$100", "No dongles, no BS", "Works with any app that uses arrow keys", the four app names, "haptic alerts at custom intervals": README.md.
- "Double Tap", "Wrist Flick": the Watch app's gesture mode names.
- UI strings ("Controlling …", "Disconnect", "Elapsed", "Pointer active", "Connected"): the Swift source.
- "Next slide, please" and "Your iPhone is the remote" are written for the film.
