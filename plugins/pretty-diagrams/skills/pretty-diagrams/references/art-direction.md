# Reusable diagram prompt

Draw a carefully composed, hand-drawn technical diagram in Excalidraw. It should feel like an excellent engineer explaining one idea on warm white paper, with the clarity of an editorial illustration.

First decide the sentence the reader should understand in five seconds. Organize the diagram around that sentence. Use a strong reading direction, quiet grouping boundaries, generous whitespace and short, specific labels. Make the central concept visually dominant. Keep secondary detail visibly secondary.

Use warm ivory (#fffdf7), dark ink (#243746), and at most three muted semantic accents: sage (#dcebdc), blue (#dceafb), peach (#fae3cf). Use accent color to explain roles, consistently across related nodes. Prefer light solid fills, rounded corners, 1.5–2px strokes and restrained roughness around 1. Use Excalidraw's handwritten font (fontFamily 1); avoid fake handwriting made with random rotations. Align shapes precisely even though their strokes are organic.

For an approximately 1400px-wide scene, start near 36–44px for the title, 24–28px for node names, 18–22px for supporting text and edge labels. Scale with density and final display size. Size boxes around their text with at least 20px internal padding. Reserve roughly 60–100px between connected regions for arrows and labels. Prefer fewer words over smaller text.

Route arrows through empty space, never through labels or unrelated nodes. Attach endpoints to the correct element. A solid arrow means a request or control action; a dashed arrow can mean a connection initiated by a client, with the arrowhead at the receiver. Label protocol or purpose beside the line. Include a small legend when different line types carry different meanings. Separate control relationships from connection initiation if they would otherwise contradict each other.

Do not add decorations that compete with topology. No gradients, shadows, stock icons, rainbow palette, huge empty group boxes or text sitting on border lines. A container means actual ownership or location, not merely proximity.

Before delivery, render and inspect: can a reader name the entry points, central service and downstream responsibilities immediately? Are all labels legible without zooming? Are directions and boundaries truthful? Revise until both visual and semantic checks pass.
