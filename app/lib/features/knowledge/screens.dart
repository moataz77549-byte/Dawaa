import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/providers.dart';

String _t(WidgetRef ref, String ar, String en) =>
    ref.watch(localeProvider) == 'ar' ? ar : en;
String _date(dynamic value) {
  final date = DateTime.tryParse('$value')?.toLocal();
  return date == null ? '—' : '${date.day}/${date.month}/${date.year}';
}

Future<void> _open(BuildContext context, String value) async {
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.userInfo.isNotEmpty) return;
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تعذر فتح الرابط الخارجي / Link unavailable'),
      ),
    );
  }
}

String _kind(String? value, WidgetRef ref) => switch (value) {
  'ingredient' => _t(ref, 'مادة فعالة', 'Ingredient'),
  'precise_ingredient' => _t(ref, 'مادة محددة الصيغة', 'Precise ingredient'),
  'chemical_compound' => _t(ref, 'مركّب كيميائي', 'Chemical compound'),
  'product' => _t(ref, 'سجل نشرة لمستحضر', 'Product label record'),
  'clinical_drug' => _t(
    ref,
    'هوية دواء بشكل وتركيز محددين',
    'Clinical drug identity',
  ),
  'research' => _t(ref, 'بحث أو مرجع ببليوغرافي', 'Research or bibliography'),
  'disease_topic' => _t(ref, 'موضوع تثقيفي', 'Educational topic'),
  _ => _t(ref, 'مصطلح أو مرجع', 'Term or reference'),
};

String _status(dynamic value, WidgetRef ref) {
  final ar = {
    'healthy': 'متاح',
    'unavailable': 'غير متاح',
    'unknown': 'حالة السحب غير معلومة',
    'retracted': 'مسحوب',
    'notice': 'إشعار تصحيح أو سحب',
    'corrected': 'مصَحّح',
  };
  return ref.watch(localeProvider) == 'ar' ? ar[value] ?? '$value' : '$value';
}

class KnowledgeSearchScreen extends ConsumerStatefulWidget {
  const KnowledgeSearchScreen({super.key, this.initialQuery = ''});
  final String initialQuery;
  @override
  ConsumerState<KnowledgeSearchScreen> createState() => _KnowledgeSearchState();
}

class _KnowledgeSearchState extends ConsumerState<KnowledgeSearchScreen> {
  late final TextEditingController controller;
  Future<dynamic>? results;
  String type = '';
  @override
  void initState() {
    super.initState();
    controller = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void search() {
    final q = controller.text.trim();
    if (q.length < 2) return;
    final params = Uri(
      queryParameters: {
        'q': q,
        'lang': ref.read(localeProvider),
        'limit': '25',
        if (type.isNotEmpty) 'type': type,
      },
    ).query;
    setState(() => results = ref.read(apiProvider).get('/v1/search?$params'));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_t(ref, 'توسيع البحث عبر الإنترنت', 'Expand search online')),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          _t(
            ref,
            'هذا فهرس سحابي تجريبي للمصطلحات والمراجع. المحتوى المحلي يبقى متاحًا من الشاشة الرئيسية.',
            'A sampled cloud index of terms and references. Local content remains available from Home.',
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          onSubmitted: (_) => search(),
          decoration: InputDecoration(
            labelText: _t(
              ref,
              'اسم أو معرّف مثل RxCUI:161',
              'Name or identifier, e.g. RxCUI:161',
            ),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: type,
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(_t(ref, 'جميع الأنواع', 'All types')),
            ),
            for (final k in [
              'ingredient',
              'chemical_compound',
              'research',
              'disease_topic',
            ])
              DropdownMenuItem(value: k, child: Text(_kind(k, ref))),
          ],
          onChanged: (v) => setState(() => type = v ?? ''),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: search,
          icon: const Icon(Icons.search),
          label: Text(_t(ref, 'بحث في الفهرس السحابي', 'Search cloud index')),
        ),
        TextButton(
          onPressed: () => context.push('/sources'),
          child: Text(_t(ref, 'استعراض المصادر وحالتها', 'Sources and status')),
        ),
        if (results != null)
          FutureBuilder<dynamic>(
            future: results,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Text(
                  _t(
                    ref,
                    'تعذر الوصول إلى الفهرس السحابي. استخدم المحتوى المحلي أو أعد المحاولة.',
                    'Cloud index unavailable. Use local content or try again.',
                  ),
                );
              }
              final rows = List<Map<String, dynamic>>.from(
                snapshot.data['items'],
              );
              if (rows.isEmpty) {
                return Text(
                  _t(
                    ref,
                    'لا توجد نتيجة في العينة المفهرسة؛ لا يعني ذلك غياب المعلومة في المصادر الأصلية.',
                    'No result in this sampled index; this does not mean the original sources contain no information.',
                  ),
                );
              }
              return Column(
                children: [
                  for (final row in rows)
                    Card(
                      child: ListTile(
                        title: Text(
                          row['arabic_name'] ?? row['preferred_name'],
                        ),
                        subtitle: Text(
                          '${_kind(row['kind'], ref)} • ${_t(ref, 'مرجع سحابي', 'Cloud reference')}',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/concept/${row['id']}'),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    ),
  );
}

class KnowledgeConceptScreen extends ConsumerStatefulWidget {
  const KnowledgeConceptScreen({super.key, required this.id});
  final String id;
  @override
  ConsumerState<KnowledgeConceptScreen> createState() =>
      _KnowledgeConceptState();
}

class _KnowledgeConceptState extends ConsumerState<KnowledgeConceptScreen> {
  late Future<dynamic> data;
  Future<dynamic>? references;
  @override
  void initState() {
    super.initState();
    data = ref
        .read(apiProvider)
        .get('/v1/concepts/${Uri.encodeComponent(widget.id)}');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(_t(ref, 'بطاقة المفهوم ومصادره', 'Concept and provenance')),
    ),
    body: FutureBuilder<dynamic>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              _t(
                ref,
                'المرجع السحابي غير متاح الآن. افتح البطاقات المنزلة من مكتبتي.',
                'Cloud reference unavailable. Open installed cards from Library.',
              ),
            ),
          );
        }
        final row = Map<String, dynamic>.from(snapshot.data);
        final facts = List<Map<String, dynamic>>.from(row['facts']);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              row['preferred_name'],
              textDirection: TextDirection.ltr,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (row['arabic_name'] != null) Text(row['arabic_name']),
            Text(_kind(row['kind'], ref)),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  _t(
                    ref,
                    'بيانات هوية أو مرجع، وليست اعتمادًا سريريًا. الترجمة العربية قيد المراجعة.',
                    'Identity or reference metadata, not clinical approval. Arabic translation is pending review.',
                  ),
                ),
              ),
            ),
            if (row['stale'] == true)
              Text(
                _t(
                  ref,
                  'تغيّر المصدر: يلزم التحقق من النسخة والمراجعة.',
                  'Source changed: version and review require verification.',
                ),
              ),
            Wrap(
              spacing: 8,
              children: [
                for (final i in row['identifiers'])
                  Chip(
                    label: Text(
                      '${i['scheme']}: ${i['value']}',
                      textDirection: TextDirection.ltr,
                    ),
                  ),
              ],
            ),
            FutureBuilder<Map<String, dynamic>?>(
              future: ref
                  .read(databaseProvider)
                  .content('knowledge-${widget.id}'),
              builder: (context, local) => local.data == null
                  ? TextButton.icon(
                      onPressed: () => context.push('/downloads'),
                      icon: const Icon(Icons.download_outlined),
                      label: Text(
                        _t(
                          ref,
                          'استعراض الحزم الاختيارية للاستخدام دون إنترنت',
                          'Browse optional offline packs',
                        ),
                      ),
                    )
                  : FilledButton.tonalIcon(
                      onPressed: () =>
                          context.push('/content/knowledge-${widget.id}'),
                      icon: const Icon(Icons.offline_pin_outlined),
                      label: Text(
                        _t(ref, 'فتح النسخة المحلية', 'Open local copy'),
                      ),
                    ),
            ),
            const SizedBox(height: 16),
            Text(
              _t(ref, 'مصادر هذه المعلومة', 'Sources for this information'),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            for (final fact in facts) _SourceFact(fact: fact),
            FilledButton.tonalIcon(
              onPressed: () => setState(
                () => references = ref
                    .read(apiProvider)
                    .get('/v1/concepts/${widget.id}/references'),
              ),
              icon: const Icon(Icons.article_outlined),
              label: Text(
                _t(
                  ref,
                  'المراجع والبحوث المرتبطة',
                  'Linked research and references',
                ),
              ),
            ),
            if (references != null)
              FutureBuilder<dynamic>(
                future: references,
                builder: (context, refs) {
                  if (refs.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (refs.hasError) {
                    return Text(
                      _t(
                        ref,
                        'تعذر فتح المراجع الآن.',
                        'References unavailable.',
                      ),
                    );
                  }
                  final rows = List<Map<String, dynamic>>.from(
                    refs.data['items'],
                  );
                  return Column(
                    children: [
                      if (rows.isEmpty)
                        Text(
                          _t(
                            ref,
                            'لا توجد روابط موثقة في هذه العينة بعد.',
                            'No documented links in this sample yet.',
                          ),
                        ),
                      for (final r in rows)
                        Card(
                          child: ListTile(
                            title: Text(r['bibliography']['title'] ?? ''),
                            subtitle: Text(
                              '${_status(r['retraction_state'], ref)} • ${r['doi'] ?? r['pmid'] ?? ''}',
                            ),
                            onTap: () => _open(
                              context,
                              r['bibliography']['source_url'] ??
                                  'https://doi.org/${r['doi']}',
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
          ],
        );
      },
    ),
  );
}

class _SourceFact extends ConsumerWidget {
  const _SourceFact({required this.fact});
  final Map<String, dynamic> fact;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provenance = Map<String, dynamic>.from(fact['provenance_snapshot']);
    final properties = Map<String, dynamic>.from(
      fact['claim_value']['properties'] ?? {},
    );
    return Card(
      child: ExpansionTile(
        title: Text(fact['source_name'] ?? fact['source_id']),
        subtitle: Text(
          '${_t(ref, 'تاريخ الجلب', 'Fetched')}: ${_date(fact['fetched_at'])}',
        ),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (properties['formula'] != null)
            Text(
              '${_t(ref, 'الصيغة', 'Formula')}: ${properties['formula']}',
              textDirection: TextDirection.ltr,
            ),
          if (properties['molecular_weight'] != null)
            Text(
              '${_t(ref, 'الوزن الجزيئي', 'Molecular weight')}: ${properties['molecular_weight']} g/mol',
              textDirection: TextDirection.ltr,
            ),
          Text(
            '${_t(ref, 'لغة الأصل', 'Original language')}: ${provenance['language']}',
          ),
          Text(
            '${_t(ref, 'تاريخ المراجعة السريرية', 'Clinical review')}: ${fact['reviewed_at'] == null ? _t(ref, 'معلّق', 'Pending') : _date(fact['reviewed_at'])}',
          ),
          Text('${_t(ref, 'الترخيص', 'License')}: ${fact['license']}'),
          Text(provenance['attribution'] ?? ''),
          TextButton.icon(
            onPressed: () => _open(context, fact['canonical_url']),
            icon: const Icon(Icons.open_in_new),
            label: Text(
              _t(
                ref,
                'المصدر الأصلي — يتطلب الإنترنت',
                'Original source — internet required',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MedicalSourcesScreen extends ConsumerStatefulWidget {
  const MedicalSourcesScreen({super.key});
  @override
  ConsumerState<MedicalSourcesScreen> createState() => _MedicalSourcesState();
}

class _MedicalSourcesState extends ConsumerState<MedicalSourcesScreen> {
  late Future<dynamic> data;
  @override
  void initState() {
    super.initState();
    data = ref.read(apiProvider).get('/v1/sources');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_t(ref, 'المصادر الطبية', 'Medical sources'))),
    body: FutureBuilder<dynamic>(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              _t(
                ref,
                'تعذر الوصول إلى سجل المصادر. المصادر محفوظة أيضًا في البطاقات المحلية.',
                'Source registry unavailable. Installed cards also retain provenance.',
              ),
            ),
          );
        }
        final rows = List<Map<String, dynamic>>.from(snapshot.data['items']);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              _t(
                ref,
                'المصدر لا يرعى التطبيق. الربط لا يعني اعتمادًا سريريًا أو إذنًا بنسخ كل محتواه.',
                'Sources do not sponsor this application. Access is not clinical approval or permission to copy all content.',
              ),
            ),
            for (final s in rows)
              Card(
                child: ExpansionTile(
                  title: Text(s['source_title']),
                  subtitle: Text(
                    '${s['health_status']} • ${_date(s['last_success_at'])}',
                  ),
                  childrenPadding: const EdgeInsets.all(16),
                  children: [
                    Text(s['license']),
                    Text(s['attribution']),
                    TextButton(
                      onPressed: () => _open(context, s['source_url']),
                      child: Text(
                        _t(
                          ref,
                          'زيارة المصدر — يتطلب الإنترنت',
                          'Visit source — internet required',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    ),
  );
}
