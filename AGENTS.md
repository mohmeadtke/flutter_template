# AI guide for this project

Read this file before you change anything. It applies to every AI assistant
(Claude, Cursor, Copilot, Codex, Gemini, ...) and to people too. The rules are
not suggestions: follow them for every feature, screen, fix or refactor, and
keep to the structure below. When a request conflicts with a rule, say so and
ask instead of quietly breaking it.

Stack: Flutter, **GetX** (state, routing, dependency injection), **Dio**
(networking), **MVC** folders. See `README.md` for the backend contract
(headers, token refresh, NID).

## Folder structure

Put each kind of code in its folder. Don't create new top-level folders in
`lib/` without asking.

```
lib/
  main.dart              init order + GetMaterialApp (only AuthController is put here)
  api/                   app_config, end_points, api_utils (Dio), interceptors,
                         api_response, api_error_messages
  model/                 data classes: fromJson / toJson, no logic, no Get
  controller/            one GetxController per page: logic + Rx state
  view/screens/          one page per file: GetView<ThatPageController>
  view/widgets/          reusable widgets: plain StatelessWidgets with parameters
  bindings/bindings.dart one Bindings class per page
  routes/app_routes.dart route names + the GetPage list
  services/              app-wide helpers with no UI (storage, device, push)
  localization/          messages.dart: every user-visible string, en + ar
  style/                 colors.dart, themes.dart
```

File names are `snake_case`: `order_model.dart`, `order_controller.dart`,
`order_screen.dart`. Classes: `OrderModel`, `OrderController`, `OrderScreen`,
`OrderBindings`.

## Pages: GetPage + Bindings + GetView (required)

Each page's controller is created when the user opens the page and deleted
(its `onClose` runs) when the page leaves the stack. To keep that:

1. **Every page is a `GetPage` in `AppRoutes.pages`** with its own `binding:`.
2. **Every binding uses `Get.lazyPut(() => XController())`.** The controller
   is created the first time the page reads it and removed with the route.
   (`Get.put` only when the page never reads the controller but its
   `onReady` must run, like `SplashBindings`.)
3. **Every page extends `GetView<XController>`** and reads `controller`.
4. **Navigate only by name:** `Get.toNamed`, `Get.offNamed`,
   `Get.offAllNamed`, with `arguments:` for data. Read them in the
   controller's `onInit` via `Get.arguments`.

Never:
- `Get.put(...)` / `Get.find(...)` inside `build()` or in a widget field.
- `Get.to(() => SomePage())` / `Navigator.push`: they skip the binding, so
  the controller is never created or never disposed.
- `permanent: true` or `fenix: true` for a page controller. Only
  `AuthController` is permanent (registered in `main.dart`).
- A `StatefulWidget` that holds page logic or API calls. Use a controller.
- One controller shared by two pages through a global `Get.put`. If two
  pages need the same data, each binding lazy-puts its controller, or the
  data lives in a service / `AuthController`.

Every controller cleans up in `onClose()`: dispose `TextEditingController`,
`ScrollController`, `FocusNode`, `AnimationController`; cancel
`StreamSubscription`, `Timer`, `Worker`; then call `super.onClose()`.

## Storage: secure storage for secrets, shared_preferences for the rest

- **Tokens and anything secret** (access/refresh tokens, passwords, keys,
  personal data) go in `flutter_secure_storage` only, through
  `services/session_storage.dart`. Never in shared_preferences, never in a
  file, never in a log.
- **Non-secret settings** (language, theme, flags, "seen onboarding") go in
  `shared_preferences` through `services/preferences_service.dart`. Add a
  getter/setter there with a private key constant; don't call
  `SharedPreferences` from controllers or views.
- **Do not use `get_storage`**, `hive`, `sqflite` or any other storage
  package unless the user explicitly asks. Never add `get_storage` to
  `pubspec.yaml`.
- A setting that must survive sign-out goes in
  `PreferencesService._deviceKeys`; everything else is wiped on sign-out.

## Networking

- Every request goes through `ApiUtils()` (`get`, `post`, `put`, `patch`,
  `delete`, `postFormData`). Don't create another `Dio`, and don't use the
  `http` package.
- Endpoint paths are constants in `api/end_points.dart`, never inline strings.
- Don't add `Authorization`, `X-Device-*`, `Accept-Language` or `X-Request-ID`
  yourself: the interceptors do it, and refresh the token too.
- 4xx come back as a `Response`; 5xx and network failures throw. Use this
  shape in every controller method:

```dart
Future<void> loadOrders() async {
  isLoading.value = true;
  errorMessage.value = null;
  try {
    final response = await ApiUtils().get(endpoint: EndPoints.orders);
    if (!response.isSuccess) {
      errorMessage.value = ApiErrorMessages.fromResponse(response);
      return;
    }
    orders.assignAll(OrderModel.listFrom(response.body));
  } catch (e) {
    debugPrint('Loading orders failed: $e');
    errorMessage.value = ApiErrorMessages.fromError(e);
  } finally {
    isLoading.value = false;
  }
}
```

- Read data with `response.body` (unwraps `{ data, error, message }`), check
  success with `response.isSuccess`.
- Show users `ApiErrorMessages`, never `response.data`, `e.toString()` or a
  raw server message. A new backend error code = one `api_<code>` row per
  language in `messages.dart`.
- Uploads: `postFormData`; never set the multipart content type by hand.

## Adding a feature (example: orders)

Do all the steps, in this order:

1. `api/end_points.dart` — `static const String orders = 'shop/mobile/Orders';`
2. `model/order_model.dart` — fields, `fromJson`, `toJson`, a `listFrom`
   that tolerates a missing or wrong-typed body (see `device_model.dart`).
3. `controller/order_controller.dart` — Rx fields, one method per API call,
   cleanup in `onClose`. Copy `home_controller.dart`.
4. `view/screens/order_screen.dart` — `GetView<OrderController>`, `Obx`
   around only the widgets that change, loading / error / empty states.
5. `bindings/bindings.dart` — `OrderBindings` with
   `Get.lazyPut(() => OrderController())`.
6. `routes/app_routes.dart` — `static const String orders = '/orders';` and
   its `GetPage(name:, page:, binding:)`.
7. `localization/messages.dart` — every new string in **both** `en` and `ar`.
8. A test in `test/` for any non-trivial logic (parsing, rules, refresh).

## Code rules

- **Views only display.** No API calls, no business logic, no storage
  calls in a widget. Views read controller fields and call controller methods.
- **Controllers have no `BuildContext`** and build no widgets (except
  `Get.snackbar` / `Get.dialog` for feedback).
- **State:** `.obs` / `Rxn<T>()` fields in the controller, `Obx` in the view.
  Keep `Obx` small. No `setState` for page state.
- **Text:** every user-visible string is a key in `messages.dart` and used
  with `.tr`. No hard-coded text in widgets. RTL (Arabic) must still look
  right: use `EdgeInsetsDirectional`, `AlignmentDirectional`,
  `start`/`end`, not `left`/`right`.
- **Style:** colors from `AppColors` / `Theme.of(context)`, never inline
  `Color(0x...)` in screens. Reuse `view/widgets/` before writing a new widget.
- **Imports inside `lib/` are relative** (`'../api/api_utils.dart'`), so the
  template can be copied under another package name.
- Single quotes, `const` constructors where possible, no unused imports,
  `async` code awaited or wrapped in `unawaited(...)`.
- Logging: `debugPrint` only (silenced in release builds). Never `print`,
  never log tokens, passwords, or full request URLs/headers.
- Models are plain Dart: null-safe `fromJson` that never throws on a missing
  field, `toJson` for anything sent to the server.

## Security

- Never commit secrets: API keys, keystores, `key.properties`,
  `google-services.json` / `GoogleService-Info.plist` of a real project unless
  the user wants them in the repo.
- Never set `badCertificateCallback` to accept everything outside the existing
  debug-only `AppConfig.allowSelfSignedCertificatesInDebug`.
- HTTPS only. Don't enable cleartext traffic (Android) or
  `NSAllowsArbitraryLoads` (iOS).
- Ask for a runtime permission only when the feature needs it, and add the
  matching `AndroidManifest.xml` entry and iOS `Info.plist` usage string.

## Packages

- Prefer what is already in `pubspec.yaml`. Before adding a package, say why
  and pick a well-maintained one from pub.dev. Never add `get_storage`.
- After adding a plugin that needs native setup, do the Android and iOS setup
  too (manifest, Info.plist, minSdk / deployment target).

## Platform folders

- The bundle ID is set only with `dart run tool/rename.dart <bundle.id> "<App Name>"`.
  Don't edit `applicationId` / `PRODUCT_BUNDLE_IDENTIFIER` by hand.
- Don't touch generated files (`GeneratedPluginRegistrant`, `Flutter/ephemeral`,
  `local.properties`).

## Before you say you're done

```bash
dart format lib test tool
flutter analyze
flutter test
```

All three must be clean. If you changed `android/` or `ios/`, also build
(`flutter build apk --debug`; iOS needs a Mac). Report anything you could not
run.
