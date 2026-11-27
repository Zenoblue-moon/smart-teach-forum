import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/services/app_state.dart';
import '../../core/services/forum_service.dart';
import '../../widgets/markdown_editor.dart';
import '../../widgets/tag_chip.dart';
import '../auth/web_login_page.dart';

/// 发布新讨论。
class ComposeDiscussionPage extends StatefulWidget {
  const ComposeDiscussionPage({Key? key}) : super(key: key);

  @override
  State<ComposeDiscussionPage> createState() => _ComposeDiscussionPageState();
}

class _ComposeDiscussionPageState extends State<ComposeDiscussionPage> {
  final _titleCtrl = TextEditingController();
  final _contentCtrl = TextEditingController();

  List<Tag> _parentTags = [];
  Map<Tag, List<Tag>> _grouped = {};
  Tag? _primary;
  final Set<String> _secondaryIds = {};

  bool _loadingTags = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadTags() async {
    try {
      final tags = await ForumService.instance.getTags();
      final grouped = ForumService.groupTags(tags);
      if (!mounted) return;
      setState(() {
        _grouped = grouped;
        _parentTags = grouped.keys.toList();
        _loadingTags = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingTags = false);
    }
  }

  Future<void> _pickPrimary() async {
    final selected = await showModalBottomSheet<Tag>(
      context: context,
      builder: (ctx) => ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('选择主板块（必选）', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final t in _parentTags)
            ListTile(
              leading: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: Color(Tag.parseColor(t.color) ?? 0xFF26A03D),
                  shape: BoxShape.circle,
                ),
              ),
              title: Text(t.name),
              subtitle: t.description.isNotEmpty ? Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis) : null,
              onTap: () => Navigator.pop(ctx, t),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
    if (selected != null) {
      setState(() {
        _primary = selected;
        _secondaryIds.clear();
      });
    }
  }

  Future<void> _submit() async {
    if (!context.read<AuthState>().isLoggedIn) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const WebLoginPage()),
      );
      if (ok != true) return;
      if (!mounted) return;
    }

    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入标题')));
      return;
    }
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入内容')));
      return;
    }
    if (_primary == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择主板块')));
      return;
    }

    setState(() => _submitting = true);
    try {
      final tagIds = <String>[_primary!.id, ..._secondaryIds];
      await ForumService.instance.createDiscussion(
        title: title,
        content: content,
        tagIds: tagIds,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('发布成功')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发布失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = _primary != null ? _grouped[_primary] ?? [] : <Tag>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('发帖'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('发布'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _titleCtrl,
            decoration: const InputDecoration(
              labelText: '标题',
              hintText: '一句话说清楚主题',
              border: OutlineInputBorder(),
            ),
            maxLength: 100,
          ),
          const SizedBox(height: 8),
          // 板块选择
          InkWell(
            onTap: _loadingTags ? null : _pickPrimary,
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: '主板块（必选）',
                border: OutlineInputBorder(),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _primary?.name ?? '点击选择板块',
                      style: TextStyle(
                        color: _primary == null ? Colors.grey : null,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          if (children.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('子板块（可选，最多 3 个）', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in children)
                  TagChip(
                    tag: c,
                    selected: _secondaryIds.contains(c.id),
                    onTap: () => setState(() {
                      if (_secondaryIds.contains(c.id)) {
                        _secondaryIds.remove(c.id);
                      } else if (_secondaryIds.length < 3) {
                        _secondaryIds.add(c.id);
                      }
                    }),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          MarkdownEditor(controller: _contentCtrl, hint: '正文（支持 Markdown）…'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
