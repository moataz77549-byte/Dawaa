import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

class ModelViewer extends StatefulWidget {
  const ModelViewer({super.key, this.file, this.bytes});
  final File? file;
  final Uint8List? bytes;
  @override
  State<ModelViewer> createState() => _ModelViewerState();
}

class _ModelViewerState extends State<ModelViewer> {
  HttpServer? server;
  WebViewController? controller;
  String? error;
  bool ready = false;
  final stopwatch = Stopwatch()..start();
  @override
  void initState() {
    super.initState();
    start();
  }

  Future<void> start() async {
    try {
      final model =
          widget.bytes ??
          (widget.file == null
              ? (await rootBundle.load(
                  'assets/models/sample/demo.glb',
                )).buffer.asUint8List()
              : await widget.file!.readAsBytes());
      final html = await rootBundle.loadString('assets/viewer/index.html');
      final js = await rootBundle.load('assets/viewer/viewer.js');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server!.listen((r) async {
        final path = r.uri.path;
        r.response.headers.set('X-Content-Type-Options', 'nosniff');
        r.response.headers.set('Cache-Control', 'no-store');
        if (r.method != 'GET') {
          r.response.statusCode = 405;
        } else if (path == '/') {
          r.response.headers.contentType = ContentType.html;
          r.response.write(html);
        } else if (path == '/viewer.js') {
          r.response.headers.contentType = ContentType(
            'application',
            'javascript',
          );
          r.response.add(js.buffer.asUint8List());
        } else if (path == '/model.glb') {
          r.response.headers.contentType = ContentType('model', 'gltf-binary');
          r.response.add(model);
        } else {
          r.response.statusCode = 404;
        }
        await r.response.close();
      });
      if (!mounted) {
        await server!.close(force: true);
        return;
      }
      final origin = 'http://127.0.0.1:${server!.port}/';
      final c = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'ViewerStatus',
          onMessageReceived: (message) {
            if (message.message == 'error' && mounted) {
              setState(() => error = '3D unavailable / تعذر عرض المجسم');
            }
            if (message.message.startsWith('metrics:')) {
              debugPrint('3D renderer ${message.message}');
            }
            if (message.message == 'ready') {
              if (mounted) {
                setState(() => ready = true);
              }
              debugPrint('3D loaded in ${stopwatch.elapsedMilliseconds}ms');
              try {
                debugPrint(
                  '3D Flutter app RSS bytes: ${ProcessInfo.currentRss}',
                );
              } catch (_) {
                debugPrint('App RSS unavailable');
              }
            }
          },
        )
        ..setNavigationDelegate(
          NavigationDelegate(
            onNavigationRequest: (r) => r.url == origin
                ? NavigationDecision.navigate
                : NavigationDecision.prevent,
          ),
        )
        ..loadRequest(Uri.parse(origin));
      if (mounted) {
        setState(() => controller = c);
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = '3D unavailable / تعذر عرض المجسم');
      }
    }
  }

  @override
  void dispose() {
    server?.close(force: true);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('3D • نموذج هندسي تجريبي')),
    body: Column(
      children: [
        if (ready) const Text('3D ready / جاهز'),
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'اسحب للتدوير، قرّب بإصبعين. نموذج هندسي أصلي CC0 وليس تشريحًا طبيًا.\nDrag to rotate; pinch to zoom. Original geometric proof, not anatomy.',
          ),
        ),
        Expanded(
          child: error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset('assets/seed/demo.png'),
                      Text(error!),
                    ],
                  ),
                )
              : controller == null
              ? const Center(child: CircularProgressIndicator())
              : WebViewWidget(controller: controller!),
        ),
        TextButton(
          onPressed: () => controller?.runJavaScript('window.resetModel()'),
          child: const Text('إعادة الضبط / Reset'),
        ),
      ],
    ),
  );
}
