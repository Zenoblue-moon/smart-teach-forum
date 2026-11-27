import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../widgets/discussion_list.dart';

/// 某个板块（标签）下的讨论列表。
class TagDiscussionsPage extends StatelessWidget {
  const TagDiscussionsPage({Key? key, required this.tag}) : super(key: key);

  final Tag tag;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tag.name)),
      body: DiscussionList(tagSlug: tag.slug),
    );
  }
}
