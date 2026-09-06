--[[
  layers.lua — per-surface layer-shell blur, verified against real
  `hyprctl layers` output on the actual target machine (Hyprland 0.56.2),
  not guessed:

    waybar   -> namespace "waybar",                layer top
    rofi     -> namespace "rofi",                  layer overlay
    swaync   -> namespace "swaync-control-center",  layer top

  V2 deliberately shipped no layer rules because those namespaces were
  unverified. They're verified now, so this file exists.

  Uses the native Hyprland Lua layer-rule API (hl.layer_rule), never the
  old hyprlang `layerrule = blur, ^(namespace)$` text syntax — this repo's
  runtime is native Lua end to end (see entrypoint.lua).

  `ignore_alpha` is the field that keeps blur off a layer-shell surface's
  genuinely transparent regions instead of blurring a big rectangle behind
  it. This matters most for SwayNC: its control-center surface reports as
  effectively fullscreen in `hyprctl layers` (xywh ~0 42 1920 1038) even
  though the visible panel only occupies the right-hand slice of that
  surface — everything else is transparent padding. Without ignore_alpha,
  blur would apply to that entire surface and read as "the whole screen
  went blurry" every time the control center opens. With it, blur only
  kicks in once a pixel's alpha crosses the threshold, i.e. only where the
  actual panel is drawn.

  Every threshold below is deliberately away from both extremes: 0 would
  blur the fully-transparent regions too (the exact bug ignore_alpha
  exists to avoid), 1.0 would require fully-opaque pixels and starve the
  blur of any surface to key off, undercutting contrast right at the edge
  of each panel. Values in the 0.10-0.25 band, one per surface below,
  keep blur confined to where each panel actually draws.

  Deliberately NOT set on any rule here, because none of them serve this
  pass's goal (blur confined to real panels, contrast preserved):
  dim_around, xray, above_lock, no_screen_share, order. Adding any of
  those would be new behavior nobody asked for in this pass.
]]

--[[
  `animation`, added this pass, is Hyprland's per-layer style override
  (LAYER_RULE_EFFECT_ANIMATION in the real source) — it only overrides the
  SHAPE (popin vs. slide, and which edge) for this one namespace; the
  shared timing/curve still comes from the layersIn/Out (position/size) and
  fadeLayersIn/Out (alpha) leaves in animations.lua. Verified against
  source (src/desktop/view/animationControllers/LayerSurfaceAnimationController.cpp):
  a style starting with "popin" takes an optional "NN%" target size, and a
  style starting with "slide" takes an optional forced edge as its second
  word (top/bottom/left/right) — "slide right" forces the surface in from
  the right edge instead of the nearest-edge default.
]]

hl.layer_rule({
  name = "blur-rofi",
  match = { namespace = "^rofi$" },
  blur = true,
  ignore_alpha = 0.2,
  -- Rofi is centered — a lateral slide makes no sense here. A tight popin
  -- reads as an elegant, deliberate appearance instead.
  animation = "popin 96%",
})

hl.layer_rule({
  name = "blur-waybar",
  match = { namespace = "^waybar$" },
  blur = true,
  ignore_alpha = 0.2,
  -- Waybar stays mapped for the whole session; this only plays on the rare
  -- occasions its layer surface is actually created/destroyed (startup,
  -- reload), never during normal use — not a continuous/looping effect.
  animation = "slide top",
})

hl.layer_rule({
  name = "blur-swaync-control-center",
  match = { namespace = "^swaync-control-center$" },
  blur = true,
  -- Slightly lower than rofi/waybar: this surface's real panel background
  -- alpha is lower once blur is live (see swaync colors.css @bg), so the
  -- threshold needs to sit a bit further down to still catch it while
  -- still skipping the surrounding transparent fullscreen padding.
  ignore_alpha = 0.15,
  -- The control center panel docks to the right edge of the screen, so it
  -- should visibly travel in from the right rather than just fading/
  -- popping in place.
  animation = "slide right",
})

--[[
  Notification popups (the small floating toasts, not the control center)
  are NOT ruled here. Their real namespace has not been measured yet —
  only swaync-control-center has. Hardcoding a guessed namespace (e.g.
  "swaync-notifications") would silently no-op at best if wrong, or
  worse, subtly match something unintended. Measure it for real with
  `notify-send` + `hyprctl layers`, then add a fourth hl.layer_rule here
  following the exact same shape as the three above.
]]
