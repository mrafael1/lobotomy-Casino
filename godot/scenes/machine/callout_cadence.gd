class_name CalloutCadence
extends RefCounted

## The pulse every full-screen TV callout beeps on.
##
## Three callouts share it — the PAIR/TRIPLE win, the power name, and the
## combo-loss warning — and it is what makes them read as the same kind of
## announcement rather than three effects that happen to overlap.
##
## It lived on WinCallouts from seam 4.2 until 4.6a, because 4.2 cut the win
## callout while the power callout was still in the machine and one of the two had
## to hold it. #197 recorded that as a debt to settle when the second callout was
## cut. This is that settlement: neither callout owns the other's timing now.
##
## A holder for constants and nothing else — deliberately not a base class. The
## callouts differ in what they show and how long they hold; all they share is
## the beat.

const BEEP_FADE_TIME := 0.1
const BEEP_PAUSE := 0.42
const BEEP_COUNT := 4

## The alpha a callout dips to on the off-beat. Not a fade to nothing: the art
## stays legible through the pulse, which is what separates a beep from a blink.
const BEEP_MIN_ALPHA := 0.18
