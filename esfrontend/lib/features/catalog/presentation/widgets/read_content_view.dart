import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../../../core/theme/typography_preset.dart';

class ReadContentView extends StatelessWidget {
  const ReadContentView({
    super.key,
    required this.dayTitle,
    required this.data,
    this.showDayTitle = true,
    this.showRawJson = true,
    this.hideHeaderFields = false,
    this.textColor = Colors.black87,
    this.sectionColor = Colors.black87,
    this.subtleColor = Colors.black54,
    this.answerScope,
    this.loadAnswer,
    this.saveAnswer,
  });

  final String dayTitle;
  final Map<String, dynamic> data;
  final bool showDayTitle;
  final bool showRawJson;
  final bool hideHeaderFields;
  final Color textColor;
  final Color sectionColor;
  final Color subtleColor;
  final String? answerScope;
  final Future<String?> Function(String questionKey)? loadAnswer;
  final Future<void> Function(String questionKey, String answer)? saveAnswer;

  @override
  Widget build(BuildContext context) {
    final contentHtml = (data['content'] ?? '').toString().trim();
    final bibleTranslations = _extractBibleTranslations(data);
    final bibleVerses = _extractBibleVerses(data);
    final readingRefs = _extractReadingRefs(data, bibleVerses);
    final hasStructured = _hasStructuredContent(
      data,
      readingRefs,
      bibleVerses,
      contentHtml,
    );
    final structuredChildren = _buildStructuredBlocks(
      context,
      readingRefs,
      bibleVerses,
      bibleTranslations,
      contentHtml,
    );
    final fallbackBlocks = _extractFallbackBlocks(data);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: DefaultTextStyle(
        style: TextStyle(
          color: textColor,
          fontSize: EsTypePreset.readBody,
          height: 1.42,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showDayTitle) ...[
              Text(
                dayTitle,
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall?.copyWith(color: sectionColor),
              ),
              const SizedBox(height: 12),
            ],
            if (hasStructured) ...structuredChildren,
            if (!hasStructured) ...fallbackBlocks,
            if (showRawJson) ...[
              const SizedBox(height: 16),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('Ver JSON original'),
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(12),
                      child: SelectableText(
                        const JsonEncoder.withIndent('  ').convert(data),
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: subtleColor),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  bool _hasStructuredContent(
    Map<String, dynamic> json,
    List<String> readingRefs,
    List<_BibleVerseItem> bibleVerses,
    String contentHtml,
  ) {
    if (contentHtml.isNotEmpty) return true;
    return readingRefs.isNotEmpty ||
        bibleVerses.isNotEmpty ||
        (json['memory_text'] ?? json['memoryVerse'] ?? '')
            .toString()
            .trim()
            .isNotEmpty ||
        json.containsKey('content');
  }

  List<Widget> _buildStructuredBlocks(
    BuildContext context,
    List<String> readingRefs,
    List<_BibleVerseItem> bibleVerses,
    List<_BibleTranslation> bibleTranslations,
    String contentHtml,
  ) {
    final children = <Widget>[];

    if (contentHtml.isNotEmpty) {
      children.add(_renderContentHtml(context, contentHtml, bibleTranslations));
      children.add(const SizedBox(height: 12));
      return children;
    }

    if (readingRefs.isNotEmpty) {
      children.add(
        Text(
          'Lee para el estudio de esta semana',
          style: TextStyle(
            color: sectionColor,
            fontSize: EsTypePreset.readSection,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
      children.add(_readingReferencesWidget(context, readingRefs, bibleVerses));
      children.add(const SizedBox(height: 20));
    }

    final memoryText = (data['memory_text'] ?? data['memoryVerse'] ?? '')
        .toString()
        .trim();
    if (memoryText.isNotEmpty) {
      children.add(
        Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: subtleColor.withValues(alpha: 0.95),
                width: 4,
              ),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Texto para memorizar',
                style: TextStyle(
                  color: sectionColor,
                  fontSize: EsTypePreset.readSection,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              _renderText(memoryText),
            ],
          ),
        ),
      );
      children.add(const SizedBox(height: 20));
    }

    if (data.containsKey('content')) {
      children.add(_renderNodeByValue(data['content'], depth: 0));
      children.add(const SizedBox(height: 12));
    }

    final extraKeys = <String>[
      'main',
      'introduction',
      'story',
      'questions',
      'sections',
    ];
    for (final key in extraKeys) {
      if (!data.containsKey(key)) continue;
      children.add(_sectionLabel(_labelForKey(key)));
      children.add(_renderNodeByValue(data[key], depth: 0));
      children.add(const SizedBox(height: 12));
    }

    return children;
  }

  Widget _renderContentHtml(
    BuildContext context,
    String contentHtml,
    List<_BibleTranslation> bibleTranslations,
  ) {
    final prepared = _injectVerseLinks(_sanitizeContentHtml(contentHtml));
    final chunks = _splitHtmlByQuestions(prepared);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(chunks.length, (index) {
        final chunk = chunks[index];
        if (chunk.isQuestion) {
          final scope = answerScope ?? dayTitle;
          final key = _buildQuestionKey(scope, chunk.questionText ?? '', index);
          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _QuestionAnswerCard(
              questionText: chunk.questionText ?? '',
              loadAnswer: loadAnswer == null ? null : () => loadAnswer!(key),
              saveAnswer: saveAnswer == null
                  ? null
                  : (answer) => saveAnswer!(key, answer),
            ),
          );
        }
        return _buildHtmlSegment(
          context: context,
          htmlData: chunk.html,
          bibleTranslations: bibleTranslations,
        );
      }),
    );
  }

  Widget _buildHtmlSegment({
    required BuildContext context,
    required String htmlData,
    required List<_BibleTranslation> bibleTranslations,
  }) {
    if (htmlData.trim().isEmpty) return const SizedBox.shrink();
    return Html(
      data: htmlData,
      style: {
        'body': Style(
          margin: Margins.zero,
          padding: HtmlPaddings.zero,
          color: textColor,
          fontSize: FontSize(EsTypePreset.readBody),
          lineHeight: const LineHeight(1.42),
        ),
        'p': Style(margin: Margins.only(bottom: 12), color: textColor),
        'hr': Style(
          margin: Margins.only(top: 10, bottom: 14),
          border: Border(
            top: BorderSide(
              color: subtleColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
        ),
        'h1': Style(margin: Margins.only(bottom: 10), color: sectionColor),
        'h2': Style(
          margin: Margins.only(bottom: 10),
          color: sectionColor,
          fontWeight: FontWeight.w700,
        ),
        'h3': Style(
          margin: Margins.only(top: 6, bottom: 10),
          color: sectionColor,
          fontWeight: FontWeight.w700,
        ),
        'blockquote': Style(
          margin: Margins.only(left: 0, right: 0, top: 8, bottom: 12),
          padding: HtmlPaddings.only(left: 14, top: 8, right: 8, bottom: 8),
          border: Border(
            left: BorderSide(
              color: subtleColor.withValues(alpha: 0.95),
              width: 4,
            ),
          ),
          color: textColor,
        ),
        'a': Style(
          color: textColor,
          textDecoration: TextDecoration.underline,
          textDecorationColor: textColor,
        ),
        'sup': Style(
          fontSize: FontSize(EsTypePreset.readSup),
          color: subtleColor,
        ),
      },
      onLinkTap: (url, attributes, element) {
        if (url == null) return;
        if (!url.startsWith('verse:')) return;
        final key = url.replaceFirst('verse:', '').trim();
        if (key.isEmpty) return;
        _openBibleVerseByKey(context, key, bibleTranslations);
      },
    );
  }

  String _sanitizeContentHtml(String html) {
    var out = html;
    // Remove inline images that create large blank spaces in the mobile reader.
    out = out.replaceAll(RegExp(r'<img[^>]*>', caseSensitive: false), '');
    // Remove empty paragraphs/spans/divs generated by source editors.
    out = out.replaceAll(
      RegExp(
        r'<(p|div|span)[^>]*>\s*(?:&nbsp;|&#160;|<br\s*/?>|\s)*\s*</\1>',
        caseSensitive: false,
      ),
      '',
    );
    // Collapse long runs of <br> to at most one.
    out = out.replaceAll(
      RegExp(r'(<br\s*/?>\s*){3,}', caseSensitive: false),
      '<br/>',
    );
    // Collapse repeated blank lines between tags.
    out = out.replaceAll(RegExp(r'>\s*\n\s*\n\s*<'), '><');
    return out.trim();
  }

  List<_HtmlQuestionChunk> _splitHtmlByQuestions(String html) {
    final chunks = <_HtmlQuestionChunk>[];
    final regex = RegExp(r'<code[^>]*>([\s\S]*?)</code>', caseSensitive: false);
    var cursor = 0;
    var index = 0;
    for (final match in regex.allMatches(html)) {
      if (match.start > cursor) {
        final before = html.substring(cursor, match.start);
        if (before.trim().isNotEmpty) {
          chunks.add(
            _HtmlQuestionChunk(html: before, isQuestion: false, index: index++),
          );
        }
      }
      final questionRaw = match.group(1) ?? '';
      final questionText = _stripHtml(questionRaw).trim();
      if (questionText.isNotEmpty) {
        chunks.add(
          _HtmlQuestionChunk(
            html: '',
            isQuestion: true,
            questionText: questionText,
            index: index++,
          ),
        );
      }
      cursor = match.end;
    }
    if (cursor < html.length) {
      final tail = html.substring(cursor);
      if (tail.trim().isNotEmpty) {
        chunks.add(
          _HtmlQuestionChunk(html: tail, isQuestion: false, index: index++),
        );
      }
    }
    return chunks;
  }

  String _stripHtml(String input) {
    var out = input.replaceAll(RegExp(r'<[^>]+>'), ' ');
    out = out
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&#39;', "'")
        .replaceAll('&quot;', '"');
    out = out.replaceAll(RegExp(r'\s+'), ' ');
    return out.trim();
  }

  String _buildQuestionKey(String scope, String questionText, int index) {
    final normalized = questionText
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return '${scope}_${index}_${normalized.hashCode}';
  }

  String _injectVerseLinks(String html) {
    return html.replaceAllMapped(
      RegExp(r'<a([^>]*?)\bverse="([^"]+)"([^>]*)>', caseSensitive: false),
      (match) {
        final before = match.group(1) ?? '';
        final verseKey = match.group(2) ?? '';
        final after = match.group(3) ?? '';
        final attrs = '$before$after';
        if (RegExp(r'\bhref\s*=', caseSensitive: false).hasMatch(attrs)) {
          return '<a$before verse="$verseKey"$after>';
        }
        return '<a$before verse="$verseKey"$after href="verse:$verseKey">';
      },
    );
  }

  void _openBibleVerseByKey(
    BuildContext context,
    String verseKey,
    List<_BibleTranslation> translations,
  ) {
    if (translations.isEmpty) {
      _openBibleVersesModal(context, const [
        _BibleVerseItem(
          reference: 'Versiculo',
          content: 'No hay datos de bible disponibles.',
        ),
      ]);
      return;
    }

    final selected = translations.first;
    final verseHtml = selected.verses[verseKey];
    if ((verseHtml ?? '').trim().isEmpty) {
      _openBibleVersesModal(context, [
        _BibleVerseItem(
          reference: verseKey,
          content: 'No se encontro el versiculo en ${selected.name}.',
          version: selected.name,
        ),
      ]);
      return;
    }

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.62,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Text(
                          selected.name.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: EsTypePreset.readBibleModalTitle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
                      children: [
                        Html(
                          data: verseHtml!,
                          style: {
                            'body': Style(
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                              color: Colors.white,
                              fontSize: FontSize(
                                EsTypePreset.readBibleModalBody,
                              ),
                              lineHeight: const LineHeight(1.4),
                            ),
                            'h1': Style(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            'h2': Style(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: FontSize(
                                EsTypePreset.readBibleModalTitle,
                              ),
                            ),
                            'h3': Style(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                            'sup': Style(
                              color: const Color(0xFFB7C0D4),
                              fontSize: FontSize(EsTypePreset.readSup),
                            ),
                            'p': Style(color: Colors.white),
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _readingReferencesWidget(
    BuildContext context,
    List<String> readingRefs,
    List<_BibleVerseItem> bibleVerses,
  ) {
    return Wrap(
      spacing: 4,
      runSpacing: 6,
      children: List.generate(readingRefs.length, (index) {
        final text = readingRefs[index];
        final suffix = index == readingRefs.length - 1 ? '.' : ';';
        return InkWell(
          onTap: bibleVerses.isEmpty
              ? null
              : () => _openBibleVersesModal(context, bibleVerses),
          child: Text(
            '$text$suffix',
            style: TextStyle(
              color: textColor,
              fontSize: EsTypePreset.readVerseLink,
              height: 1.22,
              decoration: TextDecoration.underline,
              decorationColor: textColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        );
      }),
    );
  }

  void _openBibleVersesModal(
    BuildContext context,
    List<_BibleVerseItem> verses,
  ) {
    final version = verses
        .firstWhere(
          (v) => (v.version ?? '').isNotEmpty,
          orElse: () => const _BibleVerseItem(reference: '', content: ''),
        )
        .version;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.9,
          minChildSize: 0.62,
          maxChildSize: 0.96,
          expand: false,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 30,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        Text(
                          (version ?? 'RVR1960').toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: EsTypePreset.readBibleModalTitle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(22, 8, 22, 32),
                      itemCount: verses.length,
                      itemBuilder: (context, index) {
                        final verse = verses[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                verse.reference.isEmpty
                                    ? 'Versiculo'
                                    : verse.reference,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: EsTypePreset.readBibleModalTitle,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                verse.content.isEmpty
                                    ? 'Contenido no disponible'
                                    : verse.content,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: EsTypePreset.readBibleModalBody,
                                  height: 1.38,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  List<String> _extractReadingRefs(
    Map<String, dynamic> json,
    List<_BibleVerseItem> bibleVerses,
  ) {
    final reading = json['reading'];
    if (reading is String && reading.trim().isNotEmpty) {
      return reading
          .split(RegExp(r';|\n'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (reading is List) {
      final refs = reading
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (refs.isNotEmpty) return refs;
    }
    final refsFromVerses = bibleVerses
        .map((e) => e.reference.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return refsFromVerses;
  }

  List<_BibleVerseItem> _extractBibleVerses(Map<String, dynamic> json) {
    final raw = json['bible_verses'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map<String, dynamic>>()
        .map((item) {
          final reference =
              (item['reference'] ?? item['title'] ?? item['name'] ?? '')
                  .toString()
                  .trim();
          final content =
              (item['content'] ??
                      item['text'] ??
                      item['verse'] ??
                      item['html'] ??
                      '')
                  .toString()
                  .replaceAll(RegExp(r'\s+'), ' ')
                  .trim();
          final version = (item['version'] ?? item['translation'] ?? '')
              .toString()
              .trim();
          return _BibleVerseItem(
            reference: reference,
            content: content,
            version: version,
          );
        })
        .where((e) => e.reference.isNotEmpty || e.content.isNotEmpty)
        .toList();
  }

  List<_BibleTranslation> _extractBibleTranslations(Map<String, dynamic> json) {
    final raw = json['bible'];
    if (raw is! List) return const [];

    final list = <_BibleTranslation>[];
    for (final item in raw.whereType<Map<String, dynamic>>()) {
      final name = (item['name'] ?? 'BIBLIA').toString().trim();
      final versesMapRaw = (item['verses'] is Map<String, dynamic>)
          ? item['verses'] as Map<String, dynamic>
          : <String, dynamic>{};
      final verses = <String, String>{};
      versesMapRaw.forEach((key, value) {
        final k = key.toString().trim();
        final v = (value ?? '').toString().trim();
        if (k.isNotEmpty && v.isNotEmpty) verses[k] = v;
      });
      if (verses.isNotEmpty) {
        list.add(_BibleTranslation(name: name, verses: verses));
      }
    }
    return list;
  }

  List<Widget> _extractFallbackBlocks(Map<String, dynamic> json) {
    final blocks = <Widget>[];
    final keys = <String>[
      'title',
      'date',
      'subtitle',
      'reading',
      'memory_text',
      'memoryVerse',
      'main',
      'introduction',
      'content',
      'story',
      'questions',
      'sections',
    ];

    for (final key in keys) {
      if (!json.containsKey(key)) continue;
      if (hideHeaderFields && (key == 'title' || key == 'date')) continue;
      blocks.add(_sectionLabel(_labelForKey(key)));
      blocks.add(_renderNodeByValue(json[key], depth: 0));
      blocks.add(const SizedBox(height: 12));
    }
    return blocks;
  }

  Widget _renderNodeByValue(Object? node, {required int depth}) {
    if (node == null) return const SizedBox.shrink();

    if (node is String) return _renderText(node);
    if (node is num || node is bool) {
      return Text(node.toString(), style: TextStyle(color: textColor));
    }

    if (node is List) {
      if (node.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: node
            .map((item) => _listItem(item, depth: depth + 1))
            .toList(),
      );
    }

    if (node is Map) {
      final entries = node.entries.where((e) => e.value != null).toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: entries.map((entry) {
          final k = entry.key.toString();
          final v = entry.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel(_labelForKey(k), compact: true),
                _renderNodeByValue(v, depth: depth + 1),
              ],
            ),
          );
        }).toList(),
      );
    }

    return Text(node.toString(), style: TextStyle(color: textColor));
  }

  Widget _listItem(Object? item, {required int depth}) {
    if (item is Map || item is List) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: _renderNodeByValue(item, depth: depth),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Icon(Icons.circle, size: 6, color: subtleColor),
          ),
          const SizedBox(width: 8),
          Expanded(child: _renderNodeByValue(item, depth: depth)),
        ],
      ),
    );
  }

  Widget _renderText(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    if (_looksLikeHtml(trimmed)) {
      return Html(
        data: trimmed,
        style: {
          'body': Style(
            margin: Margins.zero,
            padding: HtmlPaddings.zero,
            color: textColor,
            fontSize: FontSize(EsTypePreset.readBody),
            lineHeight: const LineHeight(1.42),
          ),
          'p': Style(margin: Margins.only(bottom: 12), color: textColor),
          'blockquote': Style(
            margin: Margins.only(left: 0, right: 0, top: 8, bottom: 8),
            padding: HtmlPaddings.all(12),
            backgroundColor: subtleColor.withValues(alpha: 0.14),
            color: textColor,
          ),
          'h1': Style(margin: Margins.only(bottom: 10), color: sectionColor),
          'h2': Style(margin: Margins.only(bottom: 10), color: sectionColor),
          'h3': Style(margin: Margins.only(bottom: 8), color: sectionColor),
          'a': Style(
            color: textColor,
            textDecoration: TextDecoration.underline,
            textDecorationColor: textColor,
          ),
        },
      );
    }

    return Text(
      trimmed,
      style: TextStyle(
        color: textColor,
        height: 1.42,
        fontSize: EsTypePreset.readBody,
      ),
    );
  }

  bool _looksLikeHtml(String text) {
    final regex = RegExp(r'</?[a-zA-Z][\s\S]*>');
    return regex.hasMatch(text);
  }

  Widget _sectionLabel(String text, {bool compact = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 4 : 8),
      child: Text(
        text,
        style: TextStyle(
          color: sectionColor,
          fontWeight: FontWeight.w700,
          fontSize: compact
              ? EsTypePreset.readCompactSection
              : EsTypePreset.readSection,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  String _labelForKey(String key) {
    final normalized = key.replaceAll('_', ' ').trim();
    if (normalized.isEmpty) return key;
    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

class _BibleVerseItem {
  const _BibleVerseItem({
    required this.reference,
    required this.content,
    this.version,
  });

  final String reference;
  final String content;
  final String? version;
}

class _BibleTranslation {
  const _BibleTranslation({required this.name, required this.verses});

  final String name;
  final Map<String, String> verses;
}

class _HtmlQuestionChunk {
  const _HtmlQuestionChunk({
    required this.html,
    required this.isQuestion,
    required this.index,
    this.questionText,
  });

  final String html;
  final bool isQuestion;
  final int index;
  final String? questionText;
}

class _QuestionAnswerCard extends StatefulWidget {
  const _QuestionAnswerCard({
    required this.questionText,
    this.loadAnswer,
    this.saveAnswer,
  });

  final String questionText;
  final Future<String?> Function()? loadAnswer;
  final Future<void> Function(String answer)? saveAnswer;

  @override
  State<_QuestionAnswerCard> createState() => _QuestionAnswerCardState();
}

class _QuestionAnswerCardState extends State<_QuestionAnswerCard> {
  late final TextEditingController _controller;
  Timer? _debounce;
  bool _didLoad = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    if (_didLoad || widget.loadAnswer == null) return;
    _didLoad = true;
    final value = await widget.loadAnswer!();
    if (!mounted) return;
    if ((value ?? '').isNotEmpty) {
      _controller.text = value!;
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    if (widget.saveAnswer == null) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () async {
      await widget.saveAnswer!(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF02204B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF223B6D), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text(
              widget.questionText,
              style: const TextStyle(
                color: Colors.white,
                fontSize: EsTypePreset.readQuestionTitle,
                fontWeight: FontWeight.w700,
                height: 1.28,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
            decoration: const BoxDecoration(
              color: Color(0xFF081225),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
            ),
            child: TextField(
              controller: _controller,
              minLines: 3,
              maxLines: 8,
              onChanged: _onChanged,
              style: const TextStyle(
                color: Colors.white,
                fontSize: EsTypePreset.readAnswerText,
                height: 1.35,
              ),
              decoration: InputDecoration(
                hintText: 'Escribe tu respuesta...',
                hintStyle: const TextStyle(color: Color(0xFF8D9AB8)),
                filled: true,
                fillColor: const Color(0xFF0A152B),
                contentPadding: const EdgeInsets.all(12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2A3D66)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF2A3D66)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF5A7FDB)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
