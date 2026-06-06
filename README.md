# sp-ice-db

sp-ice-db is a macOS application project for managing image source paths, preparing generated image datasets for AI image training, and storing human-authored and AI-authored classification metadata in reusable workspace files.

## Project Goals

1. Manage user-selected image file paths.
2. Generate AI image-training assets from registered image paths and collect the outputs in a user-selected working directory.
3. Store user-authored and AI-authored classification data for each registered image.
4. Support two metadata styles:
   - Sentence-style descriptions for tools such as Anima.
   - Tag-style captions for tools such as SDXL.
5. Provide a configurable AI connection layer, including OpenAI-compatible APIs, so the app can request image classification metadata from external AI services.
6. Save and load all image path and classification data as a workspace file.

## Documents

- [Product Requirements](docs/product-requirements.md)
- [Workspace Format Draft](docs/workspace-format.md)

## Development

The core domain logic starts as a Swift Package so it can be developed with fast unit tests before the native macOS UI is added.

GitHub issues are the source of record for project work:

- Create a GitHub issue before starting any new non-trivial task or investigation.
- If the work is small and directly related to the active task, add it to the existing issue instead of creating a separate one.
- Keep implementation notes, decisions, and follow-up work linked to the relevant issue.
- Continue using TDD for production behavior changes.

Run tests:

```sh
swift test
```

Run the macOS app shell:

```sh
swift run sp-ice-db
```

Development should follow a TDD loop:

1. Add or update a focused test that describes the behavior.
2. Run the test and confirm the expected failure when practical.
3. Implement the smallest useful production change.
4. Run `swift test`.
5. Refactor while keeping the tests green.

## Initial Scope

The first development milestone should focus on:

- Creating, opening, and saving workspace files.
- Adding, removing, and validating image paths.
- Editing human-authored sentence and tag metadata.
- Defining the AI provider configuration model.
- Preparing the internal data model for later generated-image workflows.
