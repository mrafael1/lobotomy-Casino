# Scores ledger artwork

The ledger and six suit emblems are SVG assets rendered at four source pixels
per layout unit (640x1280 frame, six 128px suit cells). They share the game's
scarlet, dark green, brass and ivory palette. No labels, statistics or dates
are baked into the art.

The scores scene keeps a 160x320 safe-area layout. Live Tiny5 headings and
values use the scores translation catalog; ending time/date formats reuse
the shared catalog. The tier sequence and saved history keys remain unchanged.

Run debug_scores_art_review.gd with ART_REVIEW_DIR to inspect English/French,
large statistics, ending dates and pointer navigation through all six tiers.
It uses sandboxed stores and asserts that history remains unchanged.
