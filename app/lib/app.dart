import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core/providers.dart';
import 'data/packs/manifest.dart';
import 'features/anatomy/viewer.dart';
import 'features/knowledge/screens.dart';

String tr(WidgetRef ref, String ar, String en) =>
    ref.watch(localeProvider) == 'ar' ? ar : en;
final router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (c, s) => const Shell()),
    GoRoute(path: '/downloads', builder: (c, s) => const DownloadsScreen()),
    GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
    GoRoute(path: '/about', builder: (c, s) => const AboutScreen()),
    GoRoute(
      path: '/content/:id',
      builder: (c, s) => ContentScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(path: '/sources', builder: (c, s) => const MedicalSourcesScreen()),
    GoRoute(
      path: '/knowledge-search',
      builder: (c, s) =>
          KnowledgeSearchScreen(initialQuery: s.uri.queryParameters['q'] ?? ''),
    ),
    GoRoute(
      path: '/concept/:id',
      builder: (c, s) => KnowledgeConceptScreen(id: s.pathParameters['id']!),
    ),
    GoRoute(path: '/model', builder: (c, s) => const ModelViewer()),
  ],
);

class DawaApp extends ConsumerWidget {
  const DawaApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(localeProvider),
        dark = ref.watch(themeProvider),
        scale = ref.watch(scaleProvider);
    final colors = ColorScheme.fromSeed(
      seedColor: const Color(0xff123f42),
      brightness: dark ? Brightness.dark : Brightness.light,
      secondary: const Color(0xffdab977),
    );
    return MaterialApp.router(
      title: 'دواء وحياة | Dawa & Hayah',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colors,
        scaffoldBackgroundColor: dark
            ? const Color(0xff122325)
            : const Color(0xfff5f8f7),
        appBarTheme: const AppBarTheme(centerTitle: false),
        cardTheme: CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(
          textScaler: TextScaler.linear(
            MediaQuery.textScalerOf(c).scale(1) * scale,
          ),
        ),
        child: child!,
      ),
    );
  }
}

class Shell extends ConsumerStatefulWidget {
  const Shell({super.key});
  @override
  ConsumerState<Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<Shell> {
  int index = 0;
  String search = '';
  bool favorites = false;
  @override
  Widget build(BuildContext context) {
    ref.watch(refreshProvider);
    final labels = [
      tr(ref, 'الرئيسية', 'Home'),
      tr(ref, 'جسم الإنسان', 'Human body'),
      tr(ref, 'الأمراض', 'Diseases'),
      tr(ref, 'الأدوية', 'Medicines'),
      tr(ref, 'مكتبتي', 'Library'),
    ];
    final cats = [null, 'anatomy', 'diseases', 'medicines', null];
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(labels[index]),
        actions: [
          IconButton(
            tooltip: tr(ref, 'التنزيلات', 'Downloads'),
            icon: const Icon(Icons.download_outlined),
            onPressed: () => context.push('/downloads'),
          ),
          IconButton(
            tooltip: tr(ref, 'الإعدادات', 'Settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          if (index == 0) ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.spa_outlined,
                    color: Color(0xffdab977),
                    size: 44,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(ref, 'دواء وحياة', 'Dawa & Hayah'),
                    style: Theme.of(
                      context,
                    ).textTheme.headlineMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr(
                      ref,
                      'علم الدواء لفهم الحياة',
                      'The science of medicine, understanding life',
                    ),
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(
                      ref,
                      'ابدأ من هنا • محتوى مدمج دون إنترنت',
                      'Start here • Built in, available offline',
                    ),
                    style: const TextStyle(color: Color(0xffdab977)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr(ref, 'معرفة موثقة، في متناولك', 'Knowledge, within reach'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                tr(
                  ref,
                  'مقدمات تعليمية وليست وصفات أو تشخيصًا. حالة المراجعة والمصادر موضحة في كل مادة.',
                  'Educational introductions, with sources and review status. They do not provide prescriptions or diagnoses.',
                ),
              ),
            ),
          ],
          TextField(
            key: const Key('search'),
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: tr(
                ref,
                'ابحث بالعربية أو الإنجليزية',
                'Search Arabic or English',
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onChanged: (x) => setState(() => search = x),
          ),
          TextButton.icon(
            onPressed: () => context.push(
              Uri(
                path: '/knowledge-search',
                queryParameters: {'q': search},
              ).toString(),
            ),
            icon: const Icon(Icons.travel_explore),
            label: Text(
              tr(ref, 'توسيع البحث عبر الإنترنت', 'Expand search online'),
            ),
          ),
          if (index == 4)
            SwitchListTile(
              title: Text(tr(ref, 'المفضلة فقط', 'Favorites only')),
              value: favorites,
              onChanged: (v) => setState(() => favorites = v),
            ),
          if (index == 1)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: FilledButton.tonalIcon(
                onPressed: () => context.push('/model'),
                icon: const Icon(Icons.view_in_ar),
                label: Text(
                  tr(
                    ref,
                    'استكشاف 3D — إثبات هندسي',
                    'Explore 3D — engineering proof',
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: db.contents(
              category: cats[index],
              search: search,
              favorites: index == 4 && favorites,
            ),
            builder: (context, s) {
              if (s.hasError) {
                return Text(
                  tr(
                    ref,
                    'تعذر فتح المحتوى المحلي',
                    'Unable to open local content',
                  ),
                );
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.data!.isEmpty) {
                return Text(tr(ref, 'لا توجد نتائج محلية', 'No local results'));
              }
              return Column(
                children: s.data!
                    .map(
                      (x) => Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Icon(
                            x['category'] == 'anatomy'
                                ? Icons.accessibility_new
                                : x['category'] == 'medicines'
                                ? Icons.medication_outlined
                                : Icons.menu_book_outlined,
                          ),
                          title: Text(x['title_${ref.watch(localeProvider)}']),
                          subtitle: Text(
                            tr(
                              ref,
                              'متاح دون إنترنت • مادة تمهيدية',
                              'Available offline • Introductory',
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => context.push('/content/${x['id']}'),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          if (index == 0)
            TextButton(
              onPressed: () => context.push('/about'),
              child: Text(
                tr(ref, 'حول التطبيق والمصادر', 'About, sources and licenses'),
              ),
            ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => index = i),
        destinations: [
          for (var i = 0; i < 5; i++)
            NavigationDestination(
              icon: Icon(
                [
                  Icons.home_outlined,
                  Icons.accessibility_new,
                  Icons.health_and_safety_outlined,
                  Icons.medication_outlined,
                  Icons.bookmarks_outlined,
                ][i],
              ),
              label: labels[i],
            ),
        ],
      ),
    );
  }
}

class ContentScreen extends ConsumerStatefulWidget {
  const ContentScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<ContentScreen> createState() => _ContentScreenState();
}

class _ContentScreenState extends ConsumerState<ContentScreen> {
  bool saved = false;
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      final db = ref.read(databaseProvider);
      await db.recordRead(widget.id);
      final b = await db.bookmarked(widget.id);
      if (mounted) {
        setState(() => saved = b);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider), db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            tooltip: tr(ref, 'مفضلة', 'Bookmark'),
            onPressed: () async {
              await db.bookmark(widget.id);
              setState(() => saved = !saved);
              ref.read(refreshProvider.notifier).state++;
            },
            icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: db.content(widget.id),
        builder: (c, s) {
          if (!s.hasData) {
            return Center(
              child: Text(
                tr(ref, 'المادة غير متاحة محليًا', 'Item unavailable locally'),
              ),
            );
          }
          final x = s.data!;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Text(
                x['title_$lang'],
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Chip(
                label: Text(
                  tr(
                    ref,
                    'مادة تعليمية • تحتاج مراجعة سريرية',
                    'Educational • Clinical review pending',
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                x['body_$lang'],
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(height: 1.8),
              ),
              const Divider(height: 40),
              Text(
                tr(ref, 'المصدر والترخيص', 'Source and license'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              SelectableText(
                '${x['source_url']}\n${x['license']}\n${x['attribution']}',
              ),
              TextButton(
                onPressed: () => launchUrl(
                  Uri.parse(x['source_url']),
                  mode: LaunchMode.externalApplication,
                ),
                child: Text(tr(ref, 'فتح المرجع', 'Open reference')),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DownloadsScreen extends ConsumerStatefulWidget {
  const DownloadsScreen({super.key});
  @override
  ConsumerState<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends ConsumerState<DownloadsScreen> {
  List<Map<String, dynamic>> catalog = [];
  String? error;
  bool loading = false;
  Map<String, int> installedVersions = {};
  Map<String, String> jobStates = {};
  Future<void> loadLocal() async {
    final db = ref.read(databaseProvider);
    final packs = await db.packs();
    final jobs = await db.jobs();
    if (mounted) {
      setState(() {
        installedVersions = {
          for (final p in packs) p['id'] as String: p['version'] as int,
        };
        jobStates = {
          for (final j in jobs) j['id'] as String: j['status'] as String,
        };
      });
    }
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    await loadLocal();
    try {
      final items = await ref.read(apiProvider).packs();
      if (mounted) {
        setState(() => catalog = items);
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = tr(
            ref,
            'تعذر الاتصال؛ المحتوى المثبت متاح أدناه.',
            'Cannot connect; installed content remains available below.',
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(load);
  }

  Future<void> download(String id) async {
    try {
      final m = PackManifest(await ref.read(apiProvider).manifest(id));
      if (!mounted) {
        return;
      }
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(tr(ref, 'تنزيل اختياري', 'Optional download')),
          content: Text(
            '${m.data['title_${ref.read(localeProvider)}']}\n${m.bytes} bytes • v${m.version}\n${m.data['license']}\n${m.data['attribution']}\nDependencies: ${m.data['dependencies']}',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(tr(ref, 'إلغاء', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(tr(ref, 'تنزيل الآن', 'Download now')),
            ),
          ],
        ),
      );
      if (ok == true) {
        await ref.read(managerProvider).install(m);
        await loadLocal();
        ref.read(refreshProvider.notifier).state++;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(managerProvider),
        db = ref.watch(databaseProvider),
        lang = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'التنزيلات', 'Downloads')),
        actions: [
          IconButton(
            onPressed: load,
            icon: const Icon(Icons.refresh),
            tooltip: tr(ref, 'تحديث الفهرس', 'Refresh catalog'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            tr(
              ref,
              'اختر ما تحتفظ به، واقرأ دون اتصال',
              'Choose what to keep, then read offline',
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (error != null) Text(error!),
          if (manager.active != null) ...[
            LinearProgressIndicator(
              value: manager.total == 0
                  ? null
                  : manager.received / manager.total,
            ),
            Text('${manager.received} / ${manager.total} bytes'),
            Wrap(
              children: [
                TextButton(
                  onPressed: manager.pause,
                  child: Text(tr(ref, 'إيقاف مؤقت', 'Pause')),
                ),
                TextButton(
                  onPressed: manager.cancel,
                  child: Text(tr(ref, 'إلغاء', 'Cancel')),
                ),
              ],
            ),
          ],
          if (manager.error != null)
            Text(
              tr(
                ref,
                'تعذر إكمال التنزيل. تحقق من الاتصال وإعدادات Wi-Fi والمساحة. تظل النسخة السابقة محفوظة.',
                'Unable to finish. Check connection, Wi-Fi settings and storage. Your previous version is preserved.',
              ),
            ),
          for (final p in catalog)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p['manifest']['title_$lang'],
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${p['manifest']['size_bytes']} bytes • v${p['version']} • ${p['manifest']['license']}',
                    ),
                    Text(
                      installedVersions[p['id']] == null
                          ? tr(ref, 'غير منزّل', 'Not downloaded')
                          : installedVersions[p['id']]! < (p['version'] as int)
                          ? tr(ref, 'تحديث متاح', 'Update available')
                          : tr(ref, 'مكتمل محليًا', 'Available offline'),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        TextButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => OnlinePreview(
                                manifest: PackManifest(
                                  Map<String, dynamic>.from(p['manifest']),
                                ),
                              ),
                            ),
                          ),
                          icon: const Icon(Icons.cloud_outlined),
                          label: Text(
                            tr(ref, 'قراءة عبر الإنترنت', 'Read online'),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          onPressed:
                              manager.active == null &&
                                  installedVersions[p['id']] != p['version']
                              ? () => download(p['id'])
                              : null,
                          icon: const Icon(Icons.download),
                          label: Text(
                            tr(
                              ref,
                              installedVersions[p['id']] == p['version']
                                  ? 'مثبت'
                                  : installedVersions[p['id']] != null
                                  ? 'تحديث'
                                  : jobStates[p['id']] == 'paused'
                                  ? 'استئناف'
                                  : 'تنزيل دون إنترنت',
                              installedVersions[p['id']] == p['version']
                                  ? 'Installed'
                                  : installedVersions[p['id']] != null
                                  ? 'Update'
                                  : jobStates[p['id']] == 'paused'
                                  ? 'Resume'
                                  : 'Download offline',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const Divider(),
          Text(
            tr(ref, 'الحزم المثبتة محليًا', 'Installed packs'),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: db.packs(),
            builder: (c, s) => Column(
              children: [
                for (final p in s.data ?? [])
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Text(
                            '${p['id']} • v${p['version']} • ${tr(ref, 'مكتمل محليًا', 'Available offline')}',
                          ),
                          Image.file(
                            File('${p['directory']}/diagram.png'),
                            height: 100,
                            errorBuilder: (c, e, s) =>
                                const Icon(Icons.broken_image_outlined),
                          ),
                          Wrap(
                            children: [
                              TextButton(
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ModelViewer(
                                      file: File('${p['directory']}/demo.glb'),
                                    ),
                                  ),
                                ),
                                child: const Text('3D Offline'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  await manager.remove(p['id']);
                                  await loadLocal();
                                  ref.read(refreshProvider.notifier).state++;
                                  if (mounted) {
                                    setState(() {});
                                  }
                                },
                                child: Text(
                                  tr(ref, 'حذف الحزمة', 'Delete pack'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: db.jobs(),
            builder: (c, s) => Column(
              children: [
                for (final j in s.data ?? [])
                  ListTile(
                    title: Text(j['id']),
                    subtitle: Text(
                      '${tr(ref, {'downloading': 'جاري التنزيل', 'installing': 'جاري التثبيت', 'complete': 'مكتمل', 'paused': 'متوقف مؤقتًا', 'cancelled': 'ملغى', 'failed': 'تعذر التنزيل'}[j['status']] ?? 'غير منزّل', j['status'])} • ${j['received']}/${j['total']}',
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class OnlinePreview extends ConsumerStatefulWidget {
  const OnlinePreview({super.key, required this.manifest});
  final PackManifest manifest;
  @override
  ConsumerState<OnlinePreview> createState() => _OnlinePreviewState();
}

class _OnlinePreviewState extends ConsumerState<OnlinePreview> {
  Map<String, dynamic>? item;
  Uint8List? image;
  String? error;
  Future<Uint8List> bytes(String path) async {
    final api = ref.read(apiProvider);
    final f = widget.manifest.files.firstWhere(
      (x) => x['relative_path'] == path,
    );
    final url = await api.access(f['asset_id']);
    final r = await api.client.get(url).timeout(const Duration(seconds: 25));
    if (r.statusCode != 200 ||
        r.bodyBytes.length != f['size_bytes'] ||
        sha256.convert(r.bodyBytes).toString() != f['sha256']) {
      throw StateError('Incomplete online asset');
    }
    return r.bodyBytes;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        final content =
            jsonDecode(utf8.decode(await bytes('content.json')))
                as Map<String, dynamic>;
        final png = await bytes('diagram.png');
        if (mounted) {
          setState(() {
            item = Map<String, dynamic>.from(content['items'][0]);
            image = png;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(
            () => error =
                '${tr(ref, 'يتطلب اتصالًا؛ عُد للمحتوى المحلي', 'Connection required; return to local content')}\n$e',
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = ref.watch(localeProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'معاينة عبر الإنترنت', 'Online preview')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            tr(
              ref,
              'يتطلب اتصالًا • غير مثبت محليًا',
              'Requires connection • Not installed offline',
            ),
          ),
          if (error != null) Text(error!),
          if (item == null && error == null) const LinearProgressIndicator(),
          if (item != null) ...[
            Text(
              item!['title_$lang'],
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SelectableText(item!['body_$lang']),
            if (image != null) Image.memory(image!),
            Text('${item!['source_url']}\n${item!['license']}'),
            TextButton(
              onPressed: () async {
                try {
                  final model = await bytes('demo.glb');
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ModelViewer(bytes: model),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => error = e.toString());
                  }
                }
              },
              child: Text(
                tr(ref, 'عرض النموذج عبر الإنترنت', 'View model online'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(refreshProvider);
    final db = ref.watch(databaseProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(tr(ref, 'الإعدادات والتخزين', 'Settings and storage')),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            key: const Key('language'),
            title: const Text('العربية / English'),
            value: ref.watch(localeProvider) == 'en',
            onChanged: (v) async {
              final l = v ? 'en' : 'ar';
              ref.read(localeProvider.notifier).state = l;
              await db.setSetting('language', l);
            },
          ),
          SwitchListTile(
            title: Text(tr(ref, 'الوضع الداكن', 'Dark mode')),
            value: ref.watch(themeProvider),
            onChanged: (v) async {
              ref.read(themeProvider.notifier).state = v;
              await db.setSetting('dark', '$v');
            },
          ),
          ListTile(
            title: Text(tr(ref, 'حجم الخط', 'Text size')),
            subtitle: Slider(
              value: ref.watch(scaleProvider),
              min: .9,
              max: 1.5,
              divisions: 6,
              onChanged: (v) {
                ref.read(scaleProvider.notifier).state = v;
                db.setSetting('scale', '$v');
              },
            ),
          ),
          FutureBuilder<String?>(
            future: db.setting('wifi_only'),
            builder: (c, s) => SwitchListTile(
              title: Text(
                tr(ref, 'التنزيل عبر Wi-Fi فقط', 'Wi-Fi downloads only'),
              ),
              subtitle: Text(
                tr(
                  ref,
                  'عطّل للسماح ببيانات الهاتف. الحد الحالي 128 MiB للحزمة.',
                  'Disable to allow mobile data. Current pack limit: 128 MiB.',
                ),
              ),
              value: s.data != 'false',
              onChanged: (v) async {
                await db.setSetting('wifi_only', '$v');
                ref.read(refreshProvider.notifier).state++;
              },
            ),
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: db.packs(),
            builder: (c, s) {
              final packs = s.data ?? [];
              final total = packs.fold<int>(
                0,
                (n, p) => n + (jsonDecode(p['manifest'])['size_bytes'] as int),
              );
              return ListTile(
                title: Text(
                  tr(ref, 'المساحة المستخدمة للحزم', 'Installed pack storage'),
                ),
                subtitle: Text('$total bytes • ${packs.length} packs'),
              );
            },
          ),
          ListTile(
            title: Text(tr(ref, 'حول التطبيق والمصادر', 'About and sources')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/about'),
          ),
        ],
      ),
    );
  }
}

class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: Text(tr(ref, 'حول دواء وحياة', 'About Dawa & Hayah')),
    ),
    body: ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Icon(Icons.spa_outlined, size: 64),
        Text(
          tr(
            ref,
            'دواء وحياة — علم الدواء لفهم الحياة',
            'Dawa & Hayah — medicine, understanding life',
          ),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 16),
        const SelectableText(
          'من تطوير وبرمجة الدكتور الصيدلاني: معتز العلقمي\nاليمن — تعز — 2026',
        ),
        const SizedBox(height: 20),
        Text(
          tr(
            ref,
            'مجاني للتعليم. لا نجمع بيانات مرضى. المقدمات مؤلفة للمشروع ولم تُعتمد سريريًا. لا تُستخدم للتشخيص أو وصف جرعات.',
            'Free for education. No patient data collected. Original introductions have no clinical sign-off. Do not use them for diagnosis or dosing.',
          ),
        ),
        const SizedBox(height: 20),
        const SelectableText(
          'Original summaries: CC-BY-4.0\nOriginal geometric proof assets: CC0\nReferences: NIH / MedlinePlus / FDA\n3D geometry is an engineering proof, not anatomy.',
        ),
        TextButton(
          onPressed: () => showLicensePage(
            context: context,
            applicationName: 'Dawa & Hayah',
          ),
          child: Text(tr(ref, 'رخص المكونات البرمجية', 'Software licenses')),
        ),
        const SizedBox(height: 16),
        Text(
          tr(
            ref,
            'لاحقًا: الأكاديمية والحاسبات والصيدلة السريرية. غير متاحة في المرحلة الأولى.',
            'Later roadmap: academy, calculators, clinical pharmacy. Not available in Stage 1.',
          ),
        ),
      ],
    ),
  );
}
