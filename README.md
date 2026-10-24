# Flutter Template

A production-ready Flutter starter for mobile apps built on a REST backend
with token-based authentication. It ships with a clean **MVC + GetX**
architecture, a hardened **Dio** networking layer with automatic token
refresh, secure session storage, Firebase push-token registration, Arabic /
English localization, and fully configured **Android** and **iOS** projects.

Start a new app by cloning it and changing one thing: the bundle ID.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.9+-0175C2?logo=dart)
![Platforms](https://img.shields.io/badge/platforms-Android%20%7C%20iOS-lightgrey)

---

## Contents

- [Features](#features)
- [Tech stack](#tech-stack)
- [Getting started](#getting-started)
- [Project structure](#project-structure)
- [Architecture](#architecture)
- [Networking](#networking)
- [Authentication and sessions](#authentication-and-sessions)
- [Push notifications (NID)](#push-notifications-nid)
- [Security](#security)
- [Adding a feature](#adding-a-feature)
- [Working with AI assistants](#working-with-ai-assistants)
- [Testing](#testing)

---

## Features

- **MVC architecture with GetX.** Each page has a route, a binding and a
  controller. The controller is created when the user opens the page and
  disposed when they leave it.
- **One networking layer.** A single `ApiUtils` client handles headers,
  auth, error parsing and uploads, so feature code stays short.
- **Automatic token refresh.** Tokens are refreshed shortly before they
  expire, a `401` is refreshed and replayed once, and parallel requests share
  a single refresh call.
- **Secure session storage.** Tokens live in the iOS Keychain or in
  Android Keystore-backed storage, never in plain preferences.
- **Device identity headers.** A stable device serial, OS, app version,
  timezone and a per-request ID go out with every call.
- **Push notifications.** The Firebase Cloud Messaging token is registered
  with the backend, kept up to date when it rotates, and removed on sign-out.
- **Localization.** Arabic and English, RTL-ready, with backend error codes
  mapped to translated messages.
- **Light and dark themes** from a single seed color.
- **Native projects ready to ship.** Android and iOS are already set up for
  every plugin the template uses, including release signing.
- **One-command rename.** `tool/rename.dart` sets the bundle ID and app name on
  both platforms.
- **AI-ready.** `AGENTS.md` gives AI coding assistants the project's rules
  and structure.
- **Tested.** The networking and session logic run against a fake backend.

## Tech stack

| Area | Package |
|---|---|
| State, routing, dependency injection | [`get`](https://pub.dev/packages/get) |
| HTTP | [`dio`](https://pub.dev/packages/dio) |
| JWT expiry and claims | [`jwt_decoder`](https://pub.dev/packages/jwt_decoder) |
| Request signing (optional) | [`crypto`](https://pub.dev/packages/crypto) |
| Secure storage (tokens) | [`flutter_secure_storage`](https://pub.dev/packages/flutter_secure_storage) |
| Preferences (settings) | [`shared_preferences`](https://pub.dev/packages/shared_preferences) |
| Device identity | `android_id`, `device_info_plus`, `package_info_plus`, `flutter_timezone` |
| Push notifications | `firebase_core`, `firebase_messaging` |
| Loading overlay | [`flutter_easyloading`](https://pub.dev/packages/flutter_easyloading) |

## Getting started

### Requirements

- Flutter 3.x (Dart 3.9 or newer)
- Android Studio / Android SDK for Android
- A Mac with Xcode for iOS

### 1. Create your project

```bash
git clone https://github.com/mohmeadtke/flutter_template.git my_app
cd my_app
rm -rf .git && git init
flutter pub get
```

### 2. Set the bundle ID and app name

```bash
dart run tool/rename.dart com.company.myapp "My App"
flutter clean
```

This updates the Android `applicationId` and `namespace` (and moves
`MainActivity.kt` to the new package), the iOS `PRODUCT_BUNDLE_IDENTIFIER`,
the display name on both platforms, and the app title in `main.dart`. You
can run it again at any time.

### 3. Point it at your backend

Edit `lib/api/app_config.dart`:

| Setting | Purpose |
|---|---|
| `baseUrl` | API root. Keep the trailing `/`. |
| `appType` | Sent as `X-App-Type` on every request. |
| `requestSigningKey` | Optional HMAC key for the `X-KEY` header. Leave `null` if unused. |
| `connectTimeout`, `receiveTimeout` | Network timeouts. |

### 4. Connect Firebase (optional)

Push notifications need a Firebase project:

```bash
flutterfire configure
```

Then pass the generated options in `lib/main.dart`:

```dart
await NidService.init(options: DefaultFirebaseOptions.currentPlatform);
```

Without Firebase the app runs normally; push registration is skipped.

### 5. Release signing

**Android.** Create `android/key.properties` (it is git-ignored):

```properties
storeFile=/absolute/path/to/upload-keystore.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

Without this file, release builds are signed with the debug key.

**iOS.** Open `ios/Runner.xcworkspace` in Xcode and select your team under
*Signing & Capabilities*. The Push Notifications capability is already
enabled and needs a paid Apple Developer account.

### 6. Run

```bash
flutter run
```

### Native configuration included

| Platform | Configured |
|---|---|
| Android | `minSdk` 24, Kotlin `MainActivity`, release signing from `key.properties`, app backup and device-to-device transfer disabled (Keystore-encrypted tokens can't be restored on another device), notification permissions from `firebase_messaging` |
| iOS | Deployment target 15.0, Swift Package Manager, push notification entitlement, `remote-notification` background mode, Arabic and English localizations |

## Project structure

```
flutter_template/
├── AGENTS.md                      Rules for AI assistants and contributors
├── CLAUDE.md                      Loads AGENTS.md for Claude Code
├── android/                       Android project (bundle ID: com.example.apptemplate)
├── ios/                           iOS project (bundle ID: com.example.apptemplate)
├── tool/
│   └── rename.dart                Sets the bundle ID and app name
├── test/
│   └── api_test.dart              Networking and session tests
└── lib/
    ├── main.dart                  Startup order and GetMaterialApp
    ├── api/
    │   ├── app_config.dart        Base URL, app type, timeouts  ← per project
    │   ├── end_points.dart        Endpoint paths
    │   ├── api_utils.dart         Dio clients: get / post / put / patch / delete / postFormData
    │   ├── interceptors.dart      Device headers, bearer token, refresh and replay
    │   ├── api_response.dart      response.isSuccess and response.body
    │   └── api_error_messages.dart  Error code → translated message
    ├── model/                     Data classes (fromJson / toJson)
    ├── controller/                One GetX controller per page
    │   └── auth_controller.dart   Session, refresh, push token, sign-out
    ├── view/
    │   ├── screens/               Pages (GetView<Controller>)
    │   └── widgets/               Reusable widgets
    ├── bindings/bindings.dart     Which controller each page creates
    ├── routes/app_routes.dart     Route names and the GetPage list
    ├── services/
    │   ├── session_storage.dart         Tokens in Keychain / Keystore
    │   ├── preferences_service.dart     Non-secret settings
    │   ├── device_identity_service.dart Device headers and stable serial
    │   └── nid_service.dart             Firebase init and FCM token
    ├── localization/messages.dart English and Arabic strings
    └── style/                     Colors and themes
```

## Architecture

The app follows **MVC**, with GetX providing state, routing and dependency
injection.

| Layer | Folder | Responsibility |
|---|---|---|
| Model | `lib/model/` | Plain data classes parsed from and serialized to JSON. |
| View | `lib/view/` | Widgets only. They read controller state and call controller methods. |
| Controller | `lib/controller/` | Page logic, API calls and reactive (`.obs`) state. |
| Services | `lib/services/` | App-wide helpers with no UI: storage, device identity, push. |

### Page lifecycle

Every page is wired the same way, so its controller lives exactly as long as
the page:

```
GetPage(name, page, binding)  →  Bindings: Get.lazyPut(() => Controller())
                              →  GetView<Controller> reads `controller`
User opens the page   → controller created, onInit / onReady run
User leaves the page  → onClose runs, controller removed from memory
```

`AuthController` is the only permanent controller. It is registered in
`main.dart` because the stored session must be loaded before the first
request.

### Startup sequence

1. Load preferences.
2. Start resolving the device identity in the background.
3. Initialize Firebase if it is configured.
4. Create the Dio clients.
5. Restore the stored session.
6. `runApp`. The splash screen sends the user to Home or Login.

## Networking

All requests go through `ApiUtils()`:

```dart
try {
  final response = await ApiUtils().get(endpoint: EndPoints.devices);
  if (!response.isSuccess) {
    errorMessage.value = ApiErrorMessages.fromResponse(response);
    return;
  }
  devices.assignAll(DeviceModel.listFrom(response.body));
} catch (e) {
  errorMessage.value = ApiErrorMessages.fromError(e);
}
```

- **4xx** responses are returned as a `Response`; **5xx** and network failures
  throw.
- `response.body` unwraps the `{ data, error, message }` envelope.
  `isSuccess` also treats `error: true` on a 200 as a failure.
- `ApiErrorMessages` turns any backend error code or network failure into a
  translated, user-friendly message. A new backend code needs one `api_<code>`
  entry per language in `messages.dart`.

### Headers sent on every request

| Header | Value |
|---|---|
| `Authorization` | `Bearer <access token>` |
| `X-Device-SN` | Android ID, or a Keychain UUID on iOS; survives reinstalls |
| `X-Device-OS` | `android`, `ios`, … |
| `X-Device-OS-Version` | e.g. `14` |
| `X-App-Version` | e.g. `1.0.0+3` |
| `X-App-Type` | `AppConfig.appType` |
| `X-Timezone` | e.g. `Asia/Baghdad` |
| `X-Request-ID` | New UUID per request, for matching server logs |
| `Accept-Language` | Current app language |
| `X-KEY` | HMAC signature, only when `AppConfig.requestSigningKey` is set |

## Authentication and sessions

- **Refresh before expiry.** A JWT that expires within 30 seconds is refreshed
  before the request is sent.
- **Refresh and replay.** A `401` triggers one refresh, then the original
  request is replayed, including multipart uploads.
- **Single-flight refresh.** Parallel requests wait for the same refresh call,
  because the backend rotates refresh tokens.
- **No recursion.** Refresh and sign-out use a separate client without the
  auth interceptor.
- **Sign-in routes are never refreshed.** A `401` there means wrong
  credentials.
- **Session end.** If the server refuses the refresh, the session is cleared
  and the user returns to Login with a clear reason (session expired or device
  removed). Being offline never signs the user out.
- **Sign-out** removes the push token, revokes the refresh token on the
  server (which frees the device slot), cancels in-flight requests, and clears
  local data.

## Push notifications (NID)

`AuthController.updateNID()` registers the device's FCM token with
`POST Notification/UpdateNID`:

- when the app opens with an active session,
- after sign-in,
- whenever Firebase rotates the token.

On sign-out the token is removed with `Notification/RemoveNID` before the
session is revoked.

## Security

- Tokens are stored only in the **iOS Keychain** / **Android
  Keystore**-encrypted storage. `shared_preferences` holds non-secret
  settings only.
- A fresh install never reuses a session left behind in the iOS Keychain by
  a deleted install.
- Android backup and device-to-device transfer are disabled for app data.
- Logging is silenced in release builds, so tokens in request URLs never
  reach the device logs.
- Certificate validation is always on in release. Self-signed certificates
  can be allowed for local servers in **debug builds only**.
- HTTPS only: cleartext traffic is not enabled on either platform.
- Signing keys (`key.properties`, `*.jks`, `*.keystore`) are git-ignored.

## Adding a feature

Example: an *Orders* page.

| Step | File | What to add |
|---|---|---|
| 1 | `api/end_points.dart` | `static const String orders = 'shop/mobile/Orders';` |
| 2 | `model/order_model.dart` | `OrderModel` with `fromJson`, `toJson`, `listFrom` |
| 3 | `controller/order_controller.dart` | Rx state, API methods, cleanup in `onClose` |
| 4 | `view/screens/order_screen.dart` | `GetView<OrderController>` with `Obx` |
| 5 | `bindings/bindings.dart` | `OrderBindings` → `Get.lazyPut(() => OrderController())` |
| 6 | `routes/app_routes.dart` | Route name and its `GetPage` with the binding |
| 7 | `localization/messages.dart` | Every new string in English and Arabic |
| 8 | `test/` | Tests for any non-trivial logic |

Navigate with `Get.toNamed(AppRoutes.orders)`.

## Working with AI assistants

[`AGENTS.md`](AGENTS.md) is the rulebook for AI coding assistants (and for
human contributors). It covers:

- GetPage + Bindings + GetView for every page,
- secure storage for tokens and `shared_preferences` for settings (never
  `get_storage`),
- the folder structure and the feature checklist,
- coding, security and testing standards.

Claude Code loads it through `CLAUDE.md`. Cursor, GitHub Copilot, Codex and
most other tools read `AGENTS.md` directly.

## Testing

```bash
flutter analyze
flutter test
```

`test/api_test.dart` runs against a fake backend and covers:

- request headers and the `X-KEY` signature,
- refresh before expiry, and one shared refresh for parallel calls,
- `401` refresh and replay (including multipart uploads),
- no refresh on sign-in routes,
- a refused refresh ending the session,
- dropping a session left over from a deleted install,
- error-code parsing for every response shape.
