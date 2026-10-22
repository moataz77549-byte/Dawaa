# ADR 002 — Android 8 viewer compatibility

The proof viewer is deliberately pinned to Three.js 0.160.1, with the matching
GLTFLoader and OrbitControls, and compiled to Chrome 58 syntax. Android API 26
can ship an old WebView; newer Three.js removes WebGL 1 support and uses newer
browser APIs. The original trusted local GLB has no external textures or links.

This is a compatibility choice for the Stage 1 engineering proof, not a claim
that all anatomy assets are supported. npm audit must cover development as well
as production packages, since this development dependency is bundled in the app.
The viewer has a 2D fallback and blocks external navigation via CSP and WebView.
Device rendering still needs to pass the API 26 and newer acceptance tests.
