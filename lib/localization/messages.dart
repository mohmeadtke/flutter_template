import 'package:get/get.dart';

/// UI strings, plus one `api_<code>` row per backend error code (read by
/// `ApiErrorMessages`). A new backend code needs a row in every language.
class Messages extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {'en': _en, 'ar': _ar};

  static const Map<String, String> _en = {
    'login': 'Login',
    'home': 'Home',
    'username': 'Phone number, e-mail or user name',
    'password': 'Password',
    'sign_out': 'Sign out',
    'error': 'Error',
    'alert': 'Notice',
    'retry': 'Retry',
    'fill_all_fields': 'Please fill all fields',
    'no_devices': 'No devices',
    'this_device': 'This device',

    // Backend / network error codes
    'api_unexpected': 'Something went wrong, please try again',
    'api_invalid_credentials':
        'The phone number, e-mail or password is incorrect',
    'api_account_locked':
        'The account is locked after several failed attempts, try again in five minutes',
    'api_user_locked_out':
        'The account is locked after several failed attempts, try again in five minutes',
    'api_two_factor_required':
        'This account uses two-step verification, which the app does not support yet',
    'api_device_limit_reached':
        'This account is signed in on the maximum number of devices. Remove one from another phone, then try again',
    'api_device_revoked':
        'This device was signed out of your account, please sign in again',
    'api_session_expired': 'Your session has ended, please sign in again',
    'api_registration_failed':
        'Registration could not be completed, please try again',
    'api_registration_expired': 'The verification expired, please verify again',
    'api_otp_invalid': 'The code is incorrect, please try again',
    'api_otp_expired': 'The code has expired, request a new one',
    'api_otp_rate_limited': 'Too many attempts, please wait a moment',
    'api_otp_resend_too_soon': 'Please wait before requesting a new code',
    'api_unauthorized': 'You are not authorized, please sign in again',
    'api_forbidden': 'You do not have access to this',
    'api_not_found': 'Not found',
    'api_server_error': 'Server error, please try again later',
    'api_no_internet':
        'No internet connection, check the network and try again',
    'api_timeout': 'The connection timed out, please try again',
    'api_canceled': 'The request was cancelled',
  };

  static const Map<String, String> _ar = {
    'login': 'تسجيل الدخول',
    'home': 'الرئيسية',
    'username': 'رقم الهاتف أو البريد الإلكتروني أو اسم المستخدم',
    'password': 'كلمة المرور',
    'sign_out': 'تسجيل الخروج',
    'error': 'خطأ',
    'alert': 'تنبيه',
    'retry': 'إعادة المحاولة',
    'fill_all_fields': 'يرجى ملء جميع الحقول',
    'no_devices': 'لا توجد أجهزة',
    'this_device': 'هذا الجهاز',

    // Backend / network error codes
    'api_unexpected': 'حدث خطأ غير متوقع، يرجى المحاولة مرة أخرى',
    'api_invalid_credentials':
        'رقم الهاتف أو البريد الإلكتروني أو كلمة المرور غير صحيحة',
    'api_account_locked':
        'تم قفل الحساب مؤقتاً بعد عدة محاولات فاشلة، يرجى المحاولة مجدداً بعد خمس دقائق',
    'api_user_locked_out':
        'تم قفل الحساب مؤقتاً بعد عدة محاولات فاشلة، يرجى المحاولة مجدداً بعد خمس دقائق',
    'api_two_factor_required':
        'هذا الحساب محمي بالتحقق بخطوتين، وهو غير مدعوم في التطبيق بعد. يرجى التواصل مع الدعم',
    'api_device_limit_reached':
        'وصلت إلى الحد الأقصى لعدد الأجهزة على هذا الحساب. من هاتف لا يزال مسجلاً الدخول احذف جهازاً، ثم حاول مرة أخرى',
    'api_device_revoked':
        'تم تسجيل خروج هذا الجهاز من حسابك، يرجى تسجيل الدخول مرة أخرى',
    'api_session_expired': 'انتهت جلستك، يرجى تسجيل الدخول مرة أخرى',
    'api_registration_failed': 'تعذر إكمال التسجيل، يرجى المحاولة مرة أخرى',
    'api_registration_expired':
        'انتهت صلاحية التحقق، يرجى التحقق مرة أخرى للمتابعة',
    'api_otp_invalid': 'رمز التحقق غير صحيح، يرجى المحاولة مرة أخرى',
    'api_otp_expired': 'انتهت صلاحية رمز التحقق، اطلب رمزاً جديداً',
    'api_otp_rate_limited':
        'محاولات كثيرة، يرجى الانتظار قليلاً ثم المحاولة مرة أخرى',
    'api_otp_resend_too_soon': 'يرجى الانتظار قليلاً قبل طلب رمز جديد',
    'api_unauthorized': 'غير مصرح، يرجى تسجيل الدخول مرة أخرى',
    'api_forbidden': 'لا تملك صلاحية الوصول',
    'api_not_found': 'غير موجود',
    'api_server_error': 'خطأ في الخادم، يرجى المحاولة لاحقاً',
    'api_no_internet': 'لا يوجد اتصال بالإنترنت، تحقق من الشبكة وحاول مرة أخرى',
    'api_timeout': 'انتهت مهلة الاتصال، يرجى المحاولة مرة أخرى',
    'api_canceled': 'تم إلغاء الطلب',
  };
}
