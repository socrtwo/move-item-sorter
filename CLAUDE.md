# CLAUDE.md

This file provides guidance for AI assistants (Claude Code and similar) working in this repository.

## Project Overview

**move-item-sorter** is an inventory management app for organizing possessions before a move. Users can document items with photos and assign each item a disposal category:

- **Move** — taking to the new location
- **Store** — putting into storage
- **Donate** — giving to charity
- **Sell** — listing for sale
- **Recycle** — sending to recycling
- **Trash** — discarding

### Target Platforms

Android, iOS, Windows, macOS, Linux, Web

## Repository State

This project is in early scaffolding stage. As of the initial commit, only the following files exist:

```
.gitignore    — Android/Gradle/IntelliJ patterns
LICENSE       — MIT (Copyright 2026 Paul D Pruitt)
README.md     — One-line project description
```

No source code has been committed yet. The `.gitignore` patterns strongly indicate the primary tech stack is **Android/Kotlin with Gradle**.

## Intended Tech Stack (inferred from .gitignore)

| Layer | Technology |
|---|---|
| Primary mobile | Android (Kotlin) |
| Build system | Gradle |
| IDE | Android Studio / IntelliJ IDEA |
| Services | Firebase / Google Services (optional) |
| Cross-platform | TBD (Kotlin Multiplatform, Flutter, or separate native apps) |

When the stack is confirmed, update this section with the exact framework choices.

## Development Workflow

### Branch Strategy

- `main` — stable, production-ready code
- Feature/fix branches — branch from `main`, open a PR to merge back
- Claude-managed branches follow the pattern `claude/<description>-<id>`

### Git Conventions

- Use clear, imperative commit messages: `Add item categorization screen`, not `added stuff`
- Commit logical units of work; avoid mixing unrelated changes
- Never force-push to `main`

### Building (Android — once source exists)

```bash
# Debug build
./gradlew assembleDebug

# Run tests
./gradlew test

# Run instrumented tests
./gradlew connectedAndroidTest

# Lint
./gradlew lint
```

### Adding a New Platform

If cross-platform support is implemented via Kotlin Multiplatform (KMP):
- Shared business logic lives in `shared/` (common source set)
- Platform-specific code goes in `androidMain/`, `iosMain/`, etc.
- Avoid putting platform APIs in the shared module

## Code Conventions (to be enforced once source exists)

### Kotlin

- Follow [Kotlin coding conventions](https://kotlinlang.org/docs/coding-conventions.html)
- Use `data class` for model types (items, categories)
- Prefer coroutines over callbacks for async work
- Use sealed classes for the disposal category enum so exhaustive `when` checks are enforced

### Architecture

The app is expected to follow **MVVM** (Model-View-ViewModel), consistent with modern Android development:

- `model/` or `data/` — data classes, repositories, data sources
- `ui/` or `presentation/` — ViewModels, Composables / XML layouts
- `domain/` — use-cases (optional layer for business logic)

When adding code, place it in the appropriate layer and do not mix UI logic into repositories.

### Item Model (expected shape)

```kotlin
data class Item(
    val id: String,
    val name: String,
    val photoUri: String?,
    val category: Category,
    val notes: String? = null
)

enum class Category {
    MOVE, STORE, DONATE, SELL, RECYCLE, TRASH
}
```

### Testing

- Unit tests go in `src/test/`
- Instrumented (device/emulator) tests go in `src/androidTest/`
- Name test functions descriptively: `givenItemWithNoPhoto_whenCategorized_thenCategoryIsSaved`
- Prefer testing ViewModels and repositories; avoid testing framework code

## Files to Never Modify

| File/Pattern | Reason |
|---|---|
| `local.properties` | Machine-local SDK path; excluded from VCS |
| `*.jks` / `*.keystore` | Signing credentials; must not be committed |
| `google-services.json` | API keys; must not be committed |
| `.gradle/` | Gradle cache; auto-generated |

## Key Constraints for AI Assistants

1. **Do not commit secrets.** `google-services.json`, keystore files, and API keys must never be added to VCS.
2. **Do not modify `main` directly.** All changes go through branches and PRs.
3. **Keep platform layers separate.** Shared logic belongs in the shared module; platform-specific code stays platform-specific.
4. **Update this file** when the tech stack is finalized or the architecture evolves significantly.
5. **Ask before adding dependencies.** New Gradle dependencies affect build time, app size, and license compliance.
