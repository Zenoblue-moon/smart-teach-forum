import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/services/forum_service.dart';
import '../../widgets/tag_chip.dart';
import 'tag_discussions_page.dart';

/// 板块浏览：按父标签分组展示子板块。
class TagsPage extends StatefulWidget {
  const TagsPage({Key? key}) : super(key: key);

  @override
  State<TagsPage> createState() => _TagsPageState();
}

class _TagsPageState extends State<TagsPage> {
  late Future<List<Tag>> _future;

  @override
  void initState() {
    super.initState();
    _future = ForumService.instance.getTags();
  }

  void _reload() {
    setState(() => _future = ForumService.instance.getTags());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('板块')),
      body: FutureBuilder<List<Tag>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || snapshot.data == null) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('板块加载失败'),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _reload,
                    icon: const Icon(Icons.refresh),
                    label: const Text('重试'),
                  ),
                ],
              ),
            );
          }

          final grouped = ForumService.groupTags(snapshot.data!);
          final parents = grouped.keys.toList();

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: parents.length,
              itemBuilder: (context, i) {
                final parent = parents[i];
                final children = grouped[parent]!;
                return _TagGroup(
                  parent: parent,
                  children: children,
                  onTapTag: _openTag,
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _openTag(Tag tag) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TagDiscussionsPage(tag: tag)),
    );
  }
}

class _TagGroup extends StatelessWidget {
  const _TagGroup({
    required this.parent,
    required this.children,
    required this.onTapTag,
  });

  final Tag parent;
  final List<Tag> children;
  final void Function(Tag) onTapTag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => onTapTag(parent),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: parent.color != null
                          ? Color(Tag.parseColor(parent.color) ?? 0xFF26A03D)
                          : scheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      parent.name,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (parent.discussionCount > 0)
                    Text(
                      '${parent.discussionCount} 帖',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                    ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 18, color: scheme.onSurfaceVariant),
                ],
              ),
            ),
            if (children.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in children) TagChip(tag: c, onTap: () => onTapTag(c)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
