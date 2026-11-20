# Review: Deck launch film (storyline A, "Next")

30 s, 1920×1080, 30 fps. Not rendered yet: stopped at the preview for approval.

## Creative calls

- The film is a presentation. Ten slides; every change is caused by a Deck input shown on screen (tap, double tap, wrist flick, pointer release).
- The phone and Watch UIs are rebuilt from this branch's Swift (`ArcRemoteView.swift`, `WatchApp/ContentView.swift`) with the exact `ArcLayout` geometry, real SF Symbols and the real macOS arrow cursor, then compared with simulator captures of the same build. Nothing in the UI is invented.
- The phone's timer counts the film's own runtime (00:00 at frame 0, 00:26 when the phone leaves), in the app's real "no limit, running" state: white arc sweeping once a minute, caption "Elapsed", orange pause button.
- Slide grounds were changed from the spec's first draft: slides behind the dark phone are paper or blue, never ink, so the device always separates. Ink is used only behind the footage and on the end card.
- The pointer beat is the payoff: the slide dims 65% around a 140 px spotlight, as `SpotlightOverlay.swift` does on the Mac.
- The name "Clicker" appears nowhere as the product. The tension slide calls the gadget being replaced a "clicker" in lower case.
- Not built: B "The clicker tax" (kinetic type on the README's prices) and C "Hands free" (the footage first, then an endless zoom through Watch, iPhone and Mac). See STORYLINES.md.

## Measured

- `check --json`: ok, 0 errors. Lint, runtime, layout, motion, contrast, craft and audio all pass.
- Timer digits equal floor(t) at every sampled frame where the phone is visible (0.3, 1.75, 3.3, 5, 6.8, 8, 15.8, 17, 18.3, 20.75, 23.3, 24.75 s).
- Footage slide changes sit at 12.98 s and 14.31 s of the film (source 5.53 s and 6.73 s at 0.9× from 4.2 s); the Watch lights its Previous then Next button 0.08 s before each.

## Looked at, not measured

- Beat, seam and phone-width review sheets, plus zooms of the Watch screen and the spotlight.

## Nobody checked

- The sound. Effects only (bundled clicks, whooshes, one pop), placed by time and not heard. There is no music bed: the catalog needs a HeyGen sign-in. Every input lands on a 120 BPM grid so a bed at that tempo drops in.
- Playback at full speed. Only still frames were inspected.

## Weakest shot

- 8.8–9.0 s, Double Tap. The Watch's Next button dims twice, which is all the app shows, but nothing on screen says the fingers never touched the glass until the slide names it. With more time: a short clip of a real double tap beside the Watch, like the wrist-flick footage.
- The device morph (phone ↔ Watch) is a blur swap around one point, not a true shape morph.

## Warnings kept on purpose

- `font_face_local_only` ×11: SF Pro Rounded and SF Pro Text are read from this Mac (`local()`), because they are the app's own faces and Apple's licence does not allow shipping the files in the repo. A cloud render or another machine would fall back to Nunito / Inter.
- `text_below_floor`: the phone's status row ("Controlling MacBook Pro", 16 px in the home framing) is ambient product UI, not reading text. Every line meant to be read is 46 px or larger.
- `contrast_aa_failure` ×5 at 19–23 s: the slide text outside the spotlight is dimmed on purpose.
- `line_unread` ("Connected", 0.2 s): the Watch layout swap, not a line to read.
- `duplicate_media_discovery_risk`: the same icon PNG is used by more than one button.

## Known gaps in the source material

- `public/demo.MP4` is 720×1280; it is shown at 608×1080 and never upscaled.
- The Mac name on the phone is the generic "MacBook Pro".
