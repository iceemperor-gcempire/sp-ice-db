# Implementation Status

This document maps the original sp-ice-db goals to the current implementation.

## Current Status

The initial core workflow is implemented:

- Workspace files can be created, opened, saved, and saved-as using `.spicedb` JSON.
- Workspace files store source folder references, source image paths, user classification data, AI classification data, AI provider profiles, generation settings, generated output records, and working-directory information.
- Users can add one or more image paths, register source folders, scan source folders recursively, remove image entries from the workspace, inspect readability status, and view readable image previews.
- Removing an image entry only unregisters it from the workspace. The original source image file is not deleted.
- Users can edit sentence-style and tag-style user metadata for each image.
- OpenAI-compatible AI provider profiles can be configured with base URL, model, API key reference, timeout, custom headers, and image-input support.
- Users can classify the selected image or every workspace image with an AI provider.
- AI classification results store sentence metadata, tag metadata, provider ID, model, and generated timestamp.
- AI classification results can be promoted into user-authored metadata.
- Users can set a working directory for generated training images.
- Users can collect selected source images into the working directory without mutating the original source files.
- OpenAI-compatible image generation can generate selected-image outputs into the working directory.
- Batch image generation can generate outputs for every workspace image.
- Generation settings presets can be created, updated, selected, and removed.
- Dataset caption export writes `.txt` sidecar files next to generated image outputs using sentence or tag metadata from user metadata, AI metadata, or user metadata with AI fallback.
- Dataset export reports missing generated files and missing captions.
- The development build can be wrapped and launched as a macOS `.app` bundle with app metadata and Dock icon setup.

## Verification

The automated test suite currently covers:

- Workspace JSON round trip, load/save, unsupported schema rejection, and failed decode handling.
- Source folder persistence, legacy workspace decoding, folder registration, duplicate handling, removal, scanning, and last-scanned tracking.
- Image path add/remove behavior, duplicate handling, file status checks, and the source-file preservation invariant.
- User and AI classification updates, AI promotion, OpenAI-compatible request building, response parsing, and client error handling.
- AI provider profile add/update/remove behavior.
- Working-directory collection, unique output filenames, and original source image preservation.
- OpenAI-compatible image generation request building, response parsing, generated output recording, and batch generation.
- Generation settings add/update/remove behavior.
- Dataset caption export for sentence and tag formats, metadata source selection, missing file reports, and empty caption reports.
- App model state transitions, dirty-state handling, running-state handling, and SwiftUI-facing workflows.
- macOS app bundle metadata and local bundle-build script shape.

Latest verification command:

```sh
swift test
```

Latest result:

```text
Executed 113 tests, with 0 failures.
```

## Follow-Up Candidates

The following items are intentionally outside the first complete core workflow and should be tracked as future issues when prioritized:

- Store API keys in macOS Keychain instead of environment/API-key references only.
- Support relative paths based on workspace location.
- Add drag-and-drop image import.
- Add generated output preview grids and richer output review tools.
- Add retry/failure queues for batch AI classification and image generation.
- Add provider-specific adapters beyond OpenAI-compatible APIs.
- Add export layout options for workflows that require copied image-plus-caption folders instead of sidecar captions next to generated outputs.
