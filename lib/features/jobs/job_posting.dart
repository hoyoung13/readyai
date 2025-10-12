import 'package:xml/xml.dart';

class JobFeed {
  const JobFeed({required this.items, required this.totalCount});

  final List<JobPosting> items;
  final int totalCount;

  factory JobFeed.fromXml(XmlDocument document) {
    final count = int.tryParse(
          document
                  .findAllElements('result_count')
                  .firstOrNull
                  ?.innerText
                  .trim() ??
              '',
        ) ??
        0;

    final items = document
        .findAllElements('resultItem')
        .map(JobPosting.fromXml)
        .toList(growable: false);

    return JobFeed(items: items, totalCount: count);
  }
}

class JobPosting {
  const JobPosting({
    required this.id,
    required this.status,
    required this.regDate,
    required this.modDate,
    required this.endDate,
    required this.title,
    required this.url,
    required this.organizationName,
  });

  final int id;
  final String status;
  final DateTime? regDate;
  final DateTime? modDate;
  final DateTime? endDate;
  final String title;
  final String url;
  final String organizationName;

  static JobPosting fromXml(XmlElement element) {
    final id =
        int.tryParse(element.getElement('itemId')?.innerText.trim() ?? '') ?? 0;
    final status = element.getElement('itemStatus')?.innerText.trim() ?? '';
    final regDate = _parseDate(element.getElement('regDate')?.innerText);
    final modDate = _parseDate(element.getElement('modDate')?.innerText);
    final endDate = _parseDate(element.getElement('endDate')?.innerText);
    final title = element.getElement('title')?.innerText.trim() ?? '';
    final url = element.getElement('itemUrl')?.innerText.trim() ?? '';
    final orgName = element.getElement('orgNm')?.innerText.trim() ?? '';

    return JobPosting(
      id: id,
      status: status,
      regDate: regDate,
      modDate: modDate,
      endDate: endDate,
      title: title,
      url: url,
      organizationName: orgName,
    );
  }
}

DateTime? _parseDate(String? value) {
  if (value == null) {
    return null;
  }

  final cleaned = value.trim();
  if (cleaned.isEmpty) {
    return null;
  }

  final normalized = cleaned.replaceAll('/', '-');
  try {
    return DateTime.parse(normalized);
  } catch (_) {
    return null;
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final iterator = this.iterator;
    if (iterator.moveNext()) {
      return iterator.current;
    }
    return null;
  }
}
