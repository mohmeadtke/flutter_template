/// `LoginResultDto` — what every sign-in route answers. Depending on the flags
/// it is a real session, a short-lived registration token, or a two-factor
/// challenge; see [isSession], [isRegistrationToken], [requiresTwoFactor].
class AuthModel {
  String? id;
  String? userName;
  List<String> roles;
  dynamic userType;
  String? accessToken;
  String? refreshToken;
  String? displayName;
  String? phoneNumber;
  String? email;
  bool isNewUser;
  bool requiresTwoFactor;

  AuthModel({
    this.id,
    this.userName,
    this.roles = const [],
    this.userType,
    this.accessToken,
    this.refreshToken,
    this.displayName,
    this.phoneNumber,
    this.email,
    this.isNewUser = false,
    this.requiresTwoFactor = false,
  });

  bool get hasAccessToken => accessToken?.isNotEmpty ?? false;

  bool get hasRefreshToken => refreshToken?.isNotEmpty ?? false;

  /// A bootstrap token that only `CreateWithContact` accepts. Derived from the
  /// missing refresh token as well as the flag, so a host that omits
  /// `isNewUser` is still read correctly.
  bool get isRegistrationToken =>
      hasAccessToken && !requiresTwoFactor && (isNewUser || !hasRefreshToken);

  /// A real session: both tokens, and not a challenge or a registration.
  bool get isSession =>
      hasAccessToken && hasRefreshToken && !requiresTwoFactor && !isNewUser;

  factory AuthModel.fromJson(Map<String, dynamic> json) => AuthModel(
    id: json['id']?.toString(),
    userName: json['userName'],
    roles: json['roles'] is List
        ? (json['roles'] as List).map((role) => role.toString()).toList()
        : const [],
    userType: json['userType'],
    accessToken: json['accessToken'],
    refreshToken: json['refreshToken'],
    displayName: json['displayName'],
    phoneNumber: json['phoneNumber'],
    email: json['email'],
    isNewUser: json['isNewUser'] == true,
    requiresTwoFactor: json['requiresTwoFactor'] == true,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'userName': userName,
    'roles': roles,
    'userType': userType,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'displayName': displayName,
    'phoneNumber': phoneNumber,
    'email': email,
    'isNewUser': isNewUser,
    'requiresTwoFactor': requiresTwoFactor,
  };
}
