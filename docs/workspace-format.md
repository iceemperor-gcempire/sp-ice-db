# Workspace Format Draft

## 1. File Type

Recommended extension:

```text
.spicedb
```

Recommended initial encoding:

```text
UTF-8 JSON
```

JSON is suitable for the first version because it is easy to inspect, migrate, diff, and test. The format can later move to a package directory or SQLite-backed document if the dataset grows large.

## 2. Top-Level Shape

```json
{
  "schemaVersion": 1,
  "workspace": {
    "id": "workspace-uuid",
    "name": "My Dataset",
    "createdAt": "2026-06-06T00:00:00Z",
    "updatedAt": "2026-06-06T00:00:00Z",
    "workingDirectory": "/Users/example/Datasets/my-dataset/generated"
  },
  "aiProviders": [
    {
      "id": "provider-uuid",
      "name": "OpenAI Compatible Provider",
      "baseURL": "https://api.example.com/v1",
      "model": "vision-model-name",
      "apiKeyRef": "macos-keychain-reference",
      "supportsImageInput": true,
      "timeoutSeconds": 60,
      "customHeaders": {}
    }
  ],
  "images": [
    {
      "id": "image-entry-uuid",
      "sourcePath": "/Users/example/Pictures/source/image001.png",
      "displayName": "image001.png",
      "notes": "",
      "classification": {
        "user": {
          "sentence": "A concise user-authored image description.",
          "tags": ["tag one", "tag two"]
        },
        "ai": {
          "sentence": "AI-authored image description.",
          "tags": ["ai tag one", "ai tag two"],
          "providerId": "provider-uuid",
          "model": "vision-model-name",
          "generatedAt": "2026-06-06T00:00:00Z"
        }
      },
      "generatedOutputs": [
        {
          "id": "output-uuid",
          "path": "/Users/example/Datasets/my-dataset/generated/image001_variant001.png",
          "status": "generated",
          "createdAt": "2026-06-06T00:00:00Z",
          "settingsId": "generation-settings-uuid"
        }
      ]
    }
  ],
  "generationSettings": [
    {
      "id": "generation-settings-uuid",
      "name": "Default training image preset",
      "providerId": "provider-uuid",
      "parameters": {}
    }
  ]
}
```

## 3. Field Notes

### `schemaVersion`

Integer version used for future migrations.

### `workspace.id`

Stable workspace identifier. This should not change when the workspace is saved under a new file name.

### `workspace.workingDirectory`

Directory where generated training images should be collected.

### `aiProviders[].apiKeyRef`

Reference to a secret stored outside the workspace file. On macOS, this should point to a Keychain item or an app-managed secure profile.

### `images[].sourcePath`

Initial version should store absolute paths. A future version can add:

```json
{
  "sourcePath": "/absolute/path/image.png",
  "relativePath": "images/image.png",
  "pathMode": "absolute"
}
```

### `classification.user`

Human-authored metadata. This is the curated source of truth when exporting user-approved captions.

### `classification.ai`

AI-authored metadata. This should retain provider and model information so results are auditable.

### `generatedOutputs`

Tracks generated image files derived from the source image. The workspace stores paths and metadata, not the binary image data itself.

## 4. Status Values

Generated output status values:

```text
pending
generated
failed
removed
```

## 5. Save Strategy

Recommended save behavior:

1. Serialize workspace to a temporary file in the same directory.
2. Validate that the serialized file can be parsed.
3. Atomically replace the previous workspace file.
4. Keep the in-memory dirty state in sync with the successful save.

## 6. Migration Strategy

When loading:

1. Read `schemaVersion`.
2. If equal to current version, decode directly.
3. If older, migrate step by step.
4. If newer, warn the user and attempt read-only loading only if safe.

## 7. Export Considerations

Future dataset export should support:

- Sentence caption files.
- Tag caption files.
- Image-plus-caption folder layouts.
- User metadata only.
- AI metadata only.
- User metadata with AI fallback.
- Validation reports for missing files or empty captions.

