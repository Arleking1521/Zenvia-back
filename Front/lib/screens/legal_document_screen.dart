import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_html_table/flutter_html_table.dart';

import '../data/legal_repository.dart';
import '../l10n/app_strings.dart';
import '../models/legal_document.dart';
import '../theme/app_colors.dart';

class LegalDocumentScreen extends StatefulWidget {
  final LegalRepository repository;
  final String type;

  const LegalDocumentScreen({
    super.key,
    required this.repository,
    required this.type,
  });

  @override
  State<LegalDocumentScreen> createState() => _LegalDocumentScreenState();
}

class _LegalDocumentScreenState extends State<LegalDocumentScreen> {
  Future<LegalDocument>? _future;
  String? _loadedLanguage;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final language = Localizations.localeOf(context).languageCode;
    if (_future == null || _loadedLanguage != language) {
      _loadedLanguage = language;
      _future = widget.repository.getDocument(
        type: widget.type,
        language: language,
      );
    }
  }

  void _reload() {
    setState(() {
      _future = widget.repository.getDocument(
        type: widget.type,
        language: _loadedLanguage ?? 'ru',
        forceRefresh: true,
      );
    });
  }

  String _fallbackTitle(BuildContext context) => widget.type == 'terms'
      ? context.tr('termsOfUse')
      : context.tr('privacyPolicy');

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(_fallbackTitle(context))),
      body: FutureBuilder<LegalDocument>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            final notPublished =
                snapshot.error is LegalDocumentNotPublishedException;
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          notPublished
                              ? Icons.description_outlined
                              : Icons.cloud_off_rounded,
                          size: 48,
                          color: AppColors.deepBlue,
                        ),
                        const SizedBox(height: 14),
                        Text(
                          notPublished
                              ? context.tr('legalNotPublished')
                              : snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        if (!notPublished) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _reload,
                            icon: const Icon(Icons.refresh_rounded),
                            label: Text(context.tr('retry')),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }

          final document = snapshot.data!;
          final effectiveDate = _formatDate(document.effectiveFrom);

          return SelectionArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          document.title.isEmpty
                              ? _fallbackTitle(context)
                              : document.title,
                          style: const TextStyle(
                            fontSize: 24,
                            height: 1.2,
                            fontWeight: FontWeight.w900,
                            color: AppColors.deepBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          effectiveDate.isEmpty
                              ? context.tr('legalVersion', {
                                  'version': document.version,
                                })
                              : context.tr('legalVersionEffective', {
                                  'version': document.version,
                                  'date': effectiveDate,
                                }),
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Divider(height: 30),
                        if (document.html.isNotEmpty)
                          Html(
                            data: document.html,
                            extensions: [
                              TableHtmlExtension(),
                            ],
                            style: {
                              'body': Style(
                                margin: Margins.zero,
                                padding: HtmlPaddings.zero,
                                fontSize: FontSize(16),
                                lineHeight: const LineHeight(1.55),
                                color: AppColors.textPrimary,
                              ),
                              'h1': Style(
                                fontSize: FontSize(24),
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepBlue,
                              ),
                              'h2': Style(
                                fontSize: FontSize(21),
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepBlue,
                              ),
                              'h3': Style(
                                fontSize: FontSize(18),
                                fontWeight: FontWeight.w800,
                                color: AppColors.deepBlue,
                              ),
                              'table': Style(
                                border: Border.all(
                                  color: const Color(0xFFDDE5F1),
                                ),
                              ),
                              'th': Style(
                                padding: HtmlPaddings.all(8),
                                fontWeight: FontWeight.bold,
                                border: Border.all(
                                  color: const Color(0xFFDDE5F1),
                                ),
                              ),
                              'td': Style(
                                padding: HtmlPaddings.all(8),
                                border: Border.all(
                                  color: const Color(0xFFDDE5F1),
                                ),
                              ),
                            },
                          )
                        else
                          SelectableText(
                            document.plainText,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.55,
                              color: AppColors.textPrimary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
