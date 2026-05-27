import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/services.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:web/web.dart' as web;

// ---- JS interop: access window.libphonenumber ----

extension on web.Window {
  external JSObject? get libphonenumber;
}

// ---- JS interop: libphonenumber-js API ----

@JS()
extension type _LibPhoneNumber._(JSObject _) implements JSObject {
  external _JSPhoneNumber parsePhoneNumber(
    JSString text, [
    JSString? defaultCountry,
  ]);

  external JSBoolean isValidPhoneNumber(
    JSString text, [
    JSString? defaultCountry,
  ]);

  external JSArray<JSString> getCountries();

  external JSString getCountryCallingCode(JSString country);
}

@JS('libphonenumber')
external _LibPhoneNumber get _lib;

@JS()
extension type _JSPhoneNumber._(JSObject _) implements JSObject {
  external JSString get countryCallingCode;
  external JSString? get country;
  external JSString get nationalNumber;

  /// E.164 formatted number, e.g. "+14175555470"
  external JSString get number;

  external JSString getType();
  external JSString format(JSString format);
}

@JS('libphonenumber.AsYouType')
extension type _AsYouType._(JSObject _) implements JSObject {
  external factory _AsYouType([JSString? defaultCountry]);
  external JSString input(JSString text);
  external void reset();
}

// ---- JS interop: Intl.DisplayNames ----

@JS('Intl.DisplayNames')
extension type _IntlDisplayNames._(JSObject _) implements JSObject {
  external factory _IntlDisplayNames(
    JSArray<JSString> locales,
    _DisplayNamesOptions options,
  );
  external JSString? of(JSString code);
}

extension type _DisplayNamesOptions._(JSObject _) implements JSObject {
  external factory _DisplayNamesOptions({required JSString type});
}

// ---- Plugin registration ----

/// Web implementation of the phone_number plugin.
///
/// Dynamically loads [libphonenumber-js](https://gitlab.com/catamphetamine/libphonenumber-js)
/// from jsDelivr CDN on first use. To avoid the CDN request, include the
/// library yourself before Flutter initialises:
///
/// ```html
/// <!-- web/index.html -->
/// <script src="https://cdn.jsdelivr.net/npm/libphonenumber-js@1/bundle/libphonenumber-min.js"></script>
/// ```
class PhoneNumberPlugin {
  static void registerWith(Registrar registrar) {
    final channel = MethodChannel(
      'np.com.rohanshrestha/phone_number',
      const StandardMethodCodec(),
      registrar,
    );
    final instance = PhoneNumberPlugin();
    channel.setMethodCallHandler(instance._handleMethodCall);
  }

  // ---- Library loading ----

  static Future<void>? _loadFuture;

  static Future<void> _ensureLibLoaded() =>
      _loadFuture ??= _loadLibphoneNumber();

  static Future<void> _loadLibphoneNumber() async {
    if (web.window.libphonenumber != null) return;

    final completer = Completer<void>();
    final script =
        web.document.createElement('script') as web.HTMLScriptElement;
    script.src =
        'https://cdn.jsdelivr.net/npm/libphonenumber-js@1/bundle/libphonenumber-min.js';
    script.onload = (web.Event _) {
      completer.complete();
    }.toJS;
    script.onerror = (web.Event _) {
      completer.completeError(
        PlatformException(
          code: 'LOAD_FAILED',
          message: 'Failed to load libphonenumber-js from CDN.',
        ),
      );
    }.toJS;
    web.document.head!.append(script);
    await completer.future;
  }

  // ---- Method call dispatcher ----

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    await _ensureLibLoaded();
    switch (call.method) {
      case 'parse':
        return _parse(call);
      case 'parse_list':
        return _parseList(call);
      case 'format':
        return _format(call);
      case 'validate':
        return _validate(call);
      case 'get_all_supported_regions':
        return _getAllSupportedRegions(call);
      case 'carrier_region_code':
        // The browser has no access to SIM/carrier information.
        return '';
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: "Method '${call.method}' not implemented on web.",
        );
    }
  }

  // ---- Helpers ----

  /// Parses [number] and returns the canonical map expected by [PhoneNumber.fromJson].
  Map<String, String> _parseToMap(String number, String? region) {
    try {
      final parsed = _lib.parsePhoneNumber(number.toJS, region?.toJS);
      return {
        'country_code': parsed.countryCallingCode.toDart,
        'region_code': parsed.country?.toDart ?? '',
        'e164': parsed.number.toDart,
        'national': parsed.format('NATIONAL'.toJS).toDart,
        'international': parsed.format('INTERNATIONAL'.toJS).toDart,
        'national_number': parsed.nationalNumber.toDart,
        'type': _mapJsType(parsed.getType().toDart),
      };
    } catch (_) {
      throw PlatformException(
        code: 'InvalidNumber',
        message: 'Number $number is invalid',
      );
    }
  }

  // ---- Method implementations ----

  Map<String, String> _parse(MethodCall call) {
    final region = call.arguments['region'] as String?;
    final string = call.arguments['string'] as String?;
    if (string == null || string.isEmpty) {
      throw PlatformException(
        code: 'InvalidParameters',
        message: "Invalid 'string' parameter.",
      );
    }
    return _parseToMap(string, region);
  }

  Map<String, Map<String, String>?> _parseList(MethodCall call) {
    final region = call.arguments['region'] as String?;
    final strings = call.arguments['strings'] as List?;
    if (strings == null || strings.isEmpty) {
      throw PlatformException(
        code: 'InvalidParameters',
        message: "Invalid 'strings' parameter.",
      );
    }
    return {
      for (final s in strings)
        s as String: () {
          try {
            return _parseToMap(s, region);
          } catch (_) {
            return null;
          }
        }(),
    };
  }

  Map<String, String> _format(MethodCall call) {
    final region = call.arguments['region'] as String;
    final string = call.arguments['string'] as String?;
    if (string == null || string.isEmpty) {
      throw PlatformException(
        code: 'InvalidParameters',
        message: "Invalid 'string' parameter.",
      );
    }
    try {
      final formatter = _AsYouType(region.toJS);
      final formatted = formatter.input(string.toJS).toDart;
      return {'formatted': formatted};
    } catch (_) {
      throw PlatformException(
        code: 'InvalidNumber',
        message: 'Number $string is invalid',
      );
    }
  }

  Map<String, bool> _validate(MethodCall call) {
    final region = call.arguments['region'] as String?;
    final string = call.arguments['string'] as String?;
    if (string == null) {
      throw PlatformException(
        code: 'InvalidParameters',
        message: "Invalid 'string' parameter.",
      );
    }
    try {
      final isValid = _lib.isValidPhoneNumber(string.toJS, region?.toJS).toDart;
      return {'isValid': isValid};
    } catch (_) {
      return {'isValid': false};
    }
  }

  List<Map<String, dynamic>> _getAllSupportedRegions(MethodCall call) {
    final locale = call.arguments['locale'] as String?;
    final countries = _lib.getCountries().toDart;

    _IntlDisplayNames? displayNames;
    try {
      final locales = locale != null
          ? [locale.toJS].toJS
          : <JSString>[].toJS;
      displayNames = _IntlDisplayNames(
        locales,
        _DisplayNamesOptions(type: 'region'.toJS),
      );
    } catch (_) {
      // Intl.DisplayNames unavailable; fall back to region code as name.
    }

    return [
      for (final c in countries)
        {
          'name': displayNames?.of(c)?.toDart ?? c.toDart,
          'code': c.toDart,
          'prefix': int.tryParse(_lib.getCountryCallingCode(c).toDart) ?? 0,
        },
    ];
  }

  // ---- Type mapping ----

  /// Maps libphonenumber-js type strings to the camelCase strings used by
  /// [PhoneNumber.fromJson] on native platforms.
  String _mapJsType(String jsType) {
    switch (jsType) {
      case 'FIXED_LINE':
        return 'fixedLine';
      case 'MOBILE':
        return 'mobile';
      case 'FIXED_LINE_OR_MOBILE':
        return 'fixedOrMobile';
      case 'TOLL_FREE':
        return 'tollFree';
      case 'PREMIUM_RATE':
        return 'premiumRate';
      case 'SHARED_COST':
        return 'sharedCost';
      case 'VOIP':
        return 'voip';
      case 'PERSONAL_NUMBER':
        return 'personalNumber';
      case 'PAGER':
        return 'pager';
      case 'UAN':
        return 'uan';
      case 'VOICEMAIL':
        return 'voicemail';
      case 'UNKNOWN':
        return 'unknown';
      default:
        return 'notParsed';
    }
  }
}
