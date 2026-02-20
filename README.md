# Layer Whale

> [!NOTE]  
> This project is no longer maintained. It is built for **Glyphs 2** and is not compatible with Glyphs 3. It was open-sourced on Feb 20th 2026.

Layer Whale is a plugin for [Glyphs 2](https://glyphsapp.com/) that makes it easy to record and playback the entire edit history of a layer. It takes a familiar Glyphs workflow and streamlines it to reduce layer clutter.

Add checkpoints while you're designing to make it easy to explore creative choices without ruining your progress. Review and showcase your design. Export time-lapse animations of your glyphs to GIF, MP4 and APNG.

For more information visit [https://makkuk.com/layerwhale/](https://makkuk.com/layerwhale/)


## Features

- **Timeline recording** -- captures layer changes as you edit glyphs, with standard and high-resolution recording modes
- **Playback** -- plays back your editing history with variable speed, scrubbing, and frame-by-frame navigation
- **Checkpoints** -- bookmark specific frames and revert to them
- **Export** -- save recordings as GIF/video, or export individual frames as new layers or background layers
- **Visualization controls** -- toggle nodes, metrics, guidelines, bounding box; zoom from 2% to 8000%; multiple aspect ratio presets; color inversion

## Requirements

- macOS 10.12.2 or later
- Glyphs 2

## Building

1. Open `LayerWhale.xcodeproj` in Xcode
2. Build the project -- the plugin installs automatically to `~/Library/Application Support/Glyphs/Plugins/`
3. Restart Glyphs

The built product is `LayerWhale.glyphsPalette`, which Glyphs loads as a palette plugin.

## Known Limitations

 - Kerning is not tracked
 - Components are tracked by reference, i.e only the current version will be displayed in the player
 - Background layers are not displayed
 - Color layers are not colored
 - Background images are not displayed in the player
 - Annotations are not displayed in the player
 - Marks (from anchors) are not shown in the player, only the anchors themselves
 - Overlap, alignment & snapping indicators, and the grid are not displayed in the player
 - The outlines are not editable or selectable in the player
 - Reporter plugins have no effect on the player. Layer Whale uses custom highly-performant drawing code to achieve suitable frame rates.
 - Issues enforcing aspect ratio on player at smaller sizes

## License

This project is licensed under the [MIT License](LICENSE).
