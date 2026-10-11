# Shoulder Guide

A cross-platform Flutter application for browsing plain-language shoulder condition information. It has condition-name search, direct filters, and deterministic weighted matching when symptom filters are selected. It does not diagnose or store answers.

## Run the app

Install Flutter, then from this folder run:

```sh
flutter pub get
flutter run -d web-server
```

Flutter prints the local URL when the server starts. The current responsive browser preview is at <http://127.0.0.1:8767> and is open in the Codex browser. This simulated environment works without an Android or iOS simulator.

You can also launch on a connected device or installed simulator with `flutter devices`, followed by `flutter run -d <device-id>`. Flutter platform targets are included for Android, iOS, web, macOS, Windows, and Linux. Simulator availability depends on the local platform SDKs.

Build release outputs with:

```sh
flutter build web
flutter build apk
flutter build ios
flutter build macos
```

The included GitHub Actions workflow builds and publishes the web app from `main` to GitHub Pages. In the repository settings, select **Settings → Pages → GitHub Actions** as the publishing source.

## Project structure

```text
lib/main.dart             Flutter screens, navigation, and matching engine
assets/data/               Source-of-truth JSON records
  symptoms.json            Controlled searchable/filterable symptom choices
  conditions.json          Plain-language condition information and resource links
  matches.json             One row per symptom-condition link and its weight
  references.json          Reference metadata shown on condition pages
  recovery_resources.json  Structured recovery summaries linked to conditions
  videos.json              Curated video metadata, links, and review records
  temporary_pain_options.json Source-linked temporary comfort information
assets/fonts/               Bundled Source Sans 3 font files and SIL OFL license
android/ ios/ web/         Flutter platform projects
macos/ windows/ linux/     Flutter desktop platform projects
.github/workflows/         GitHub Pages release workflow
```

The score is the sum of configured weights for selected symptom filters. It only orders matching conditions and is not shown as a probability. The weights are placeholders and have not been clinically validated. A qualified clinician should review the condition list, symptom links, weights, descriptions, and safety wording before public use.

## Safety and scope

The Urgent Signs filter displays an emergency or prompt-care notice above the condition list when selected. The list cannot cover every emergency or every cause of shoulder pain. The current emergency message uses 911 and should be localized for the intended audience.

There are no accounts, analytics, treatment plans, machine learning, or server-side user records. Source links open through the platform browser. Runtime data is bundled with the app.

## Video resources

Video entries are managed in `assets/data/videos.json`. Add a listing only after checking the publisher, video identity, and relevance. `sourceVerified` and `relevanceChecked` are separate from `medicalReviewStatus`; the app does not claim medical review unless that status is explicitly recorded. The current listings have not been medically reviewed for this app, and captions have not been verified. No videos are embedded or loaded automatically; users open the publisher page themselves.

Exercise videos require an explicit `clinician_approved` safety review and condition-specific approval IDs. They are hidden while urgent signs are selected and cannot appear for a condition unless that condition has been approved in the video record. No exercise demonstrations are currently listed. Keep written precautions alongside every resource, and periodically recheck links and content.

## Temporary pain relief

General, source-linked comfort information is managed in `assets/data/temporary_pain_options.json`. Each option lists its applicable condition IDs, precautions, references, and source/content verification status. The app does not recommend a specific medicine or dose. Routine options are withheld while urgent signs are selected and are only linked to the non-urgent conditions listed in the data. This content has not been medically reviewed for this app; a qualified clinician should review it before public use.

The interface uses locally bundled Source Sans 3 files under the SIL Open Font License; see `assets/fonts/OFL.txt`.
