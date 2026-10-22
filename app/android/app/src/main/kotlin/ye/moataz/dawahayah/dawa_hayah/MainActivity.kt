package ye.moataz.dawahayah.dawa_hayah

import android.os.StatFs
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ye.moataz.dawa/storage")
            .setMethodCallHandler { call, result ->
                if (call.method == "availableBytes") {
                    result.success(StatFs(filesDir.absolutePath).availableBytes)
                } else if (call.method == "webViewAvailable") {
                    result.success(WebView.getCurrentWebViewPackage() != null)
                } else result.notImplemented()
            }
    }
}
