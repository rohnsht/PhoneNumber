package np.com.rohanshrestha.phone_number

import android.content.Context
import android.telephony.TelephonyManager
import com.google.i18n.phonenumbers.NumberParseException
import com.google.i18n.phonenumbers.PhoneNumberUtil
import com.google.i18n.phonenumbers.PhoneNumberUtil.PhoneNumberType
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.FlutterPlugin.FlutterPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import java.util.Locale

class PhoneNumberPlugin : FlutterPlugin, MethodCallHandler {
    private var channel: MethodChannel? = null
    private var context: Context? = null

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        channel =
            MethodChannel(flutterPluginBinding.binaryMessenger, "np.com.rohanshrestha/phone_number")
        channel!!.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPluginBinding) {
        channel!!.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "parse" -> parse(call, result)
            "parse_list" -> parseList(call, result)
            "format" -> format(call, result)
            "validate" -> validate(call, result)
            "get_all_supported_regions" -> getAllSupportedRegions(call, result)
            "carrier_region_code" -> carrierRegionCode(result)
            else -> result.notImplemented()
        }
    }

    private fun getAllSupportedRegions(call: MethodCall, result: MethodChannel.Result) {
        val map: MutableList<Map<String, Any>> = ArrayList()

        val locale: Locale
        val identifier = call.argument<String>("locale")
        locale = if (identifier == null) {
            Locale.getDefault()
        } else {
            Locale(identifier)
        }

        for (region in PhoneNumberUtil.getInstance().supportedRegions) {
            val res: MutableMap<String, Any> = HashMap()
            res["name"] = Locale("", region).getDisplayCountry(locale)
            res["code"] = region
            res["prefix"] = PhoneNumberUtil.getInstance().getCountryCodeForRegion(region)
            map.add(res)
        }

        result.success(map)
    }

    private fun carrierRegionCode(result: MethodChannel.Result) {
        val tm = context!!.getSystemService(Context.TELEPHONY_SERVICE) as TelephonyManager
        result.success(tm.networkCountryIso)
    }

    private fun validate(call: MethodCall, result: MethodChannel.Result) {
        val region = call.argument<String>("region")
        val number = call.argument<String>("string")

        if (number == null) {
            result.error("InvalidParameters", "Invalid 'string' parameter.", null)
            return
        }

        try {
            val util = PhoneNumberUtil.getInstance()
            val phoneNumber = util.parse(number, region)
            val isValid = if (region == null
            ) util.isValidNumber(phoneNumber)
            else util.isValidNumberForRegion(phoneNumber, region)

            val res = HashMap<String, Boolean>()
            res["isValid"] = isValid

            result.success(res)
        } catch (exception: Exception) {
            result.error("InvalidNumber", "Number $number is invalid", null)
        }
    }

    private fun format(call: MethodCall, result: MethodChannel.Result) {
        val region = call.argument<String>("region")
        val number = call.argument<String>("string")

        if (number == null) {
            result.error("InvalidParameters", "Invalid 'string' parameter.", null)
            return
        }

        try {
            val util = PhoneNumberUtil.getInstance()
            val formatter = util.getAsYouTypeFormatter(region)

            var formatted = ""
            formatter.clear()
            for (character in number.toCharArray()) {
                formatted = formatter.inputDigit(character)
            }

            val res = HashMap<String, String>()
            res["formatted"] = formatted

            result.success(res)
        } catch (exception: Exception) {
            result.error("InvalidNumber", "Number $number is invalid", null)
        }
    }

    private fun parseStringAndRegion(
        string: String, region: String?,
        util: PhoneNumberUtil
    ): HashMap<String, String>? {
        try {
            val phoneNumber = util.parse(string, region)

            if (!util.isValidNumber(phoneNumber)) {
                return null
            }

            // Try to parse the string to a phone number for a given region.

            // If the parsing is successful, we return a map containing :
            // - the number in the E164 format
            // - the number in the international format
            // - the number formatted as a national number and without the international prefix
            // - the type of number (might not be 100% accurate)
            return object : HashMap<String, String>() {
                init {
                    val type = util.getNumberType(phoneNumber)
                    val countryCode = phoneNumber.countryCode
                    put("type", numberTypeToString(type))
                    put("e164", util.format(phoneNumber, PhoneNumberUtil.PhoneNumberFormat.E164))
                    put(
                        "international",
                        util.format(phoneNumber, PhoneNumberUtil.PhoneNumberFormat.INTERNATIONAL)
                    )
                    put(
                        "national",
                        util.format(phoneNumber, PhoneNumberUtil.PhoneNumberFormat.NATIONAL)
                    )
                    put("country_code", countryCode.toString())
                    put("region_code", util.getRegionCodeForNumber(phoneNumber).toString())
                    put("national_number", phoneNumber.nationalNumber.toString())
                }
            }
        } catch (e: NumberParseException) {
            return null
        }
    }

    private fun parse(call: MethodCall, result: MethodChannel.Result) {
        val region = call.argument<String>("region")
        val string = call.argument<String>("string")

        if (string.isNullOrEmpty()) {
            result.error("InvalidParameters", "Invalid 'string' parameter.", null)
        } else {
            val util = PhoneNumberUtil.getInstance()

            val res = parseStringAndRegion(string, region, util)

            if (res != null) {
                result.success(res)
            } else {
                result.error("InvalidNumber", "Number $string is invalid", null)
            }
        }
    }

    private fun parseList(call: MethodCall, result: MethodChannel.Result) {
        val region = call.argument<String>("region")
        val strings = call.argument<List<String>>("strings")

        if (strings.isNullOrEmpty()) {
            result.error("InvalidParameters", "Invalid 'strings' parameter.", null)
        } else {
            val util = PhoneNumberUtil.getInstance()

            val res = HashMap<String, HashMap<String, String>?>(strings.size)

            for (string in strings) {
                val stringResult = parseStringAndRegion(string, region, util)

                res[string] = stringResult
            }

            result.success(res)
        }
    }

    private fun numberTypeToString(type: PhoneNumberType): String {
        return when (type) {
            PhoneNumberType.FIXED_LINE -> "fixedLine"
            PhoneNumberType.MOBILE -> "mobile"
            PhoneNumberType.FIXED_LINE_OR_MOBILE -> "fixedOrMobile"
            PhoneNumberType.TOLL_FREE -> "tollFree"
            PhoneNumberType.PREMIUM_RATE -> "premiumRate"
            PhoneNumberType.SHARED_COST -> "sharedCost"
            PhoneNumberType.VOIP -> "voip"
            PhoneNumberType.PERSONAL_NUMBER -> "personalNumber"
            PhoneNumberType.PAGER -> "pager"
            PhoneNumberType.UAN -> "uan"
            PhoneNumberType.VOICEMAIL -> "voicemail"
            PhoneNumberType.UNKNOWN -> "unknown"
            else -> "notParsed"
        }
    }
}
