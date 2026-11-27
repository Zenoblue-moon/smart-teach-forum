import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/services/app_state.dart';
import '../../core/services/forum_service.dart';
import '../../widgets/discussion_list.dart';
import '../../widgets/tag_chip.dart';
import '../tags/tag_discussions_page.dart';

/// 搜索页：关键词检索 + 最近搜索 + 热门板块。
class SearchPage extends StatefulWidget {
  const SearchPage({Key? key}) : super(key: key);

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();
  String _submitted = '';
  late Future<List<Tag>> _tagsFuture;

  @override
  void initState() {
    super.initState();
    _tagsFuture = ForumService.instance.getTags();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final q = value.trim();
    if (q.isEmpty) return;
    setState(() => _submitted = q);
    context.read<SettingsState>().addRecentSearch(q);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsState>();
    final recent = settings.recentSearches;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            hintText: '搜索帖子、关键词…',
            border: InputBorder.none,
          ),
          onSubmitted: _submit,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _submit(_controller.text),
          ),
        ],
      ),
      body: _submitted.isEmpty
          ? _buildSuggestions(context, recent)
          : DiscussionList(query: _submitted),
    );
  }

  Widget _buildSuggestions(BuildContext context, List<String> recent) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (recent.isNotEmpty) ...[
          Row(
            children: [
              const Text('最近搜索', style: TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(
                onPressed: () => context.read<SettingsState>().clearRecentSearches(),
                child: const Text('清空'),
              ),
            ],
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in recent)
                ActionChip(
                  label: Text(q),
                  onPressed: () {
                    _controller.text = q;
                    _submit(q);
                  },
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
        const Text('热门板块', style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        FutureBuilder<List<Tag>>(
          future: _tagsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.data == null) return const SizedBox.shrink();
            final parents = snapshot.data!.where((t) => !t.isChild).toList();
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in parents)
                  TagChip(
                    tag: p,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => TagDiscussionsPage(tag: p)),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
