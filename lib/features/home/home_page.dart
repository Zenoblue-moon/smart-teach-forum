import 'package:flutter/material.dart';

import '../../widgets/discussion_list.dart';
import '../compose/compose_discussion_page.dart';
import '../search/search_page.dart';

/// 首页：最新 / 最热 / 最近回复 讨论流。
class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('智教联盟论坛'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: '搜索',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SearchPage()),
            ),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '最新'),
            Tab(text: '最热'),
            Tab(text: '最近回复'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: '发帖',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ComposeDiscussionPage()),
        ),
        child: const Icon(Icons.edit),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          DiscussionList(sort: '-createdAt'),
          DiscussionList(sort: '-commentCount'),
          DiscussionList(sort: '-lastPostedAt'),
        ],
      ),
    );
  }
}
