import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/services/app_state.dart';
import '../../core/services/forum_service.dart';
import '../../widgets/markdown_editor.dart';
import '../auth/web_login_page.dart';

/// 回帖页。
class ReplyPage extends StatefulWidget {
  const ReplyPage({
    Key? key,
    required this.discussionId,
    this.discussionTitle = '',
    this.quoteContent,
    this.quoteAuthor,
    this.postId,
  }) : super(key: key);

  final String discussionId;
  final String discussionTitle;
  final String? quoteContent;
  final String? quoteAuthor;

  /// 被回复楼层的帖子 id，用于生成帖子提及（@xxx#p{id}）。
  final String? postId;

  @override
  State<ReplyPage> createState() => _ReplyPageState();
}

class _ReplyPageState extends State<ReplyPage> {
  late final TextEditingController _contentCtrl;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _contentCtrl = TextEditingController(text: _buildInitial());
  }

  @override
  void dispose() {
    _contentCtrl.dispose();
    super.dispose();
  }

  String _buildInitial() {
    final author = widget.quoteAuthor;
    final parts = <String>[];

    // 若为回复某楼层，生成帖子提及，使其在列表中显示为「回复了 X」。
    if (widget.postId != null && widget.postId!.isNotEmpty) {
      final name = (author != null && author.isNotEmpty) ? author : '楼层';
      parts.add('@"$name"#p${widget.postId}');
    }

    final q = widget.quoteContent;
    if (q != null && q.isNotEmpty) {
      final quoted = q.split('\n').map((l) => '> $l').join('\n');
      parts.add(quoted);
    }

    return parts.isEmpty ? '' : '${parts.join('\n\n')}\n\n';
  }

  Future<void> _submit() async {
    if (!context.read<AuthState>().isLoggedIn) {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const WebLoginPage()),
      );
      if (ok != true) return;
      if (!mounted) return;
    }

    final content = _contentCtrl.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请输入回复内容')));
      return;
    }

    setState(() => _submitting = true);
    try {
      await ForumService.instance.createPost(
        discussionId: widget.discussionId,
        content: content,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('回复失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('回复'),
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
                  : const Text('回复'),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.discussionTitle.isNotEmpty) ...[
            Text(
              widget.discussionTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
          ],
          MarkdownEditor(controller: _contentCtrl, hint: '输入回复内容…'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
