import 'dart:convert';

import 'package:http/http.dart' as http;

import '../api_client.dart';
import '../config.dart';
import '../models.dart';

/// 分页结果。
class PageResult<T> {
  PageResult(this.items, {this.nextOffset});

  final List<T> items;
  final int? nextOffset;

  bool get hasMore => nextOffset != null;
}

/// 论坛数据服务，封装各类 Flarum API 调用。
class ForumService {
  ForumService._();

  static final ForumService instance = ForumService._();

  ApiClient get _api => ApiClient.instance;

  // ---------------------------------------------------------------------
  // 标签 / 板块
  // ---------------------------------------------------------------------

  /// 全部标签（含父子结构）。
  Future<List<Tag>> getTags() async {
    final doc = await _api.get('/tags');
    return doc.dataList
        .map((e) => Tag.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 将标签组织为「父标签 -> 子标签列表」。
  static Map<Tag, List<Tag>> groupTags(List<Tag> all) {
    final parents = <Tag, List<Tag>>{};
    final childrenByParent = <String, List<Tag>>{};
    for (final t in all) {
      if (t.isChild) {
        final pid = t.parentId ?? '';
        childrenByParent.putIfAbsent(pid, () => []).add(t);
      }
    }
    for (final t in all) {
      if (!t.isChild) {
        parents[t] = childrenByParent[t.id] ?? [];
      }
    }
    return parents;
  }

  // ---------------------------------------------------------------------
  // 讨论
  // ---------------------------------------------------------------------

  static const Map<String, String> _includeDiscussion =
      {'include': 'user,lastPostedUser,tags,firstPost'};

  /// 讨论列表。
  ///
  /// [sort] 取值：`-createdAt`（最新）、`-commentCount`（最热）、
  /// `-lastPostedAt`（最近回复）、`default`（综合）。
  /// [tagSlug] 按板块筛选（注意：Flarum 的 `filter[tag]` 使用标签 slug，而非数字 id）；
  /// [author] 按作者筛选（注意：Flarum 的 `filter[author]` 使用用户名 username，而非数字 id）；
  /// [query] 关键词搜索。
  Future<PageResult<Discussion>> getDiscussions({
    String sort = '-lastPostedAt',
    String? tagSlug,
    String? query,
    String? author,
    int offset = 0,
    int limit = AppConfig.pageSize,
  }) async {
    final q = <String, String>{
      ..._includeDiscussion,
      'sort': sort,
      'page[offset]': '$offset',
      'page[limit]': '$limit',
    };
    if (tagSlug != null) q['filter[tag]'] = tagSlug;
    if (author != null) q['filter[author]'] = author;
    if (query != null && query.trim().isNotEmpty) {
      q['filter[q]'] = query.trim();
    }
    final doc = await _api.get('/discussions', query: q);
    final items = doc.dataList
        .map((e) => Discussion.fromJson(e as Map<String, dynamic>, doc))
        .toList();
    return PageResult(items, nextOffset: items.length >= limit ? offset + limit : null);
  }

  /// 单个讨论详情（含首帖与标签）。
  Future<Discussion> getDiscussion(String id) async {
    final doc = await _api.get('/discussions/$id', query: {
      ..._includeDiscussion,
      'include': 'user,lastPostedUser,tags,firstPost',
    });
    return Discussion.fromJson(doc.data!, doc);
  }

  /// 讨论的楼层列表（按楼层号排序、分页）。
  Future<PageResult<Post>> getPosts(
    String discussionId, {
    int offset = 0,
    int limit = AppConfig.pageSize,
  }) async {
    final doc = await _api.get('/posts', query: {
      'include': 'user',
      'filter[discussion]': discussionId,
      'sort': 'number',
      'page[offset]': '$offset',
      'page[limit]': '$limit',
    });
    final items = doc.dataList
        .map((e) => Post.fromJson(e as Map<String, dynamic>, doc))
        .toList();
    return PageResult(items, nextOffset: items.length >= limit ? offset + limit : null);
  }

  // ---------------------------------------------------------------------
  // 用户
  // ---------------------------------------------------------------------

  Future<ForumUser?> getUser(String id) async {
    try {
      final doc = await _api.get('/users/$id');
      if (doc.data == null) return null;
      return ForumUser.fromJson(doc.data!);
    } catch (_) {
      return null;
    }
  }

  // ---------------------------------------------------------------------
  // 赞/踩（fof/gamification）与表情回应（fof/reactions）
  // ---------------------------------------------------------------------

  /// 表情回应列表。
  Future<List<Reaction>> getReactions() async {
    final doc = await _api.get('/reactions');
    return doc.dataList
        .map((e) => Reaction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// 赞 / 踩投票。
  ///
  /// fof/gamification 的投票 API：`PATCH /posts/{id}`，attributes 为
  /// `[upvote, downvote, "vote"]` 数组；取消时两者都为 false。
  Future<Post> vote(
    String postId, {
    required bool upvote,
    required bool downvote,
  }) async {
    final doc = await _api.patch('/posts/$postId', body: {
      'data': {
        'type': 'posts',
        'id': postId,
        'attributes': [upvote, downvote, 'vote'],
      },
    });
    return Post.fromJson(doc.data!, doc);
  }

  /// 发表情回应；[reactionId] 为 null 表示取消当前回应。
  Future<Post> react(String postId, String? reactionId) async {
    final doc = await _api.patch('/posts/$postId', body: {
      'data': {
        'type': 'posts',
        'id': postId,
        'attributes': {'reaction': reactionId},
      },
    });
    return Post.fromJson(doc.data!, doc);
  }

  // ---------------------------------------------------------------------
  // 通知
  // ---------------------------------------------------------------------

  Future<PageResult<NotificationItem>> getNotifications({
    int offset = 0,
    int limit = AppConfig.pageSize,
  }) async {
    final doc = await _api.get('/notifications', query: {
      'page[offset]': '$offset',
      'page[limit]': '$limit',
    });
    final items = doc.dataList
        .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
        .toList();
    return PageResult(items, nextOffset: items.length >= limit ? offset + limit : null);
  }

  /// 标记全部通知已读。
  Future<void> markAllNotificationsRead() async {
    await _api.post('/notifications');
  }

  // ---------------------------------------------------------------------
  // 发帖 / 回帖
  // ---------------------------------------------------------------------

  /// 发布新讨论。
  Future<Discussion> createDiscussion({
    required String title,
    required String content,
    required List<String> tagIds,
  }) async {
    final doc = await _api.post('/discussions', body: {
      'data': {
        'type': 'discussions',
        'attributes': {'title': title, 'content': content},
        'relationships': {
          'tags': {
            'data': [
              for (final id in tagIds) {'type': 'tags', 'id': id},
            ],
          },
        },
      },
    });
    return Discussion.fromJson(doc.data!, doc);
  }

  /// 回帖。
  Future<Post> createPost({
    required String discussionId,
    required String content,
  }) async {
    final doc = await _api.post('/posts', body: {
      'data': {
        'type': 'posts',
        'attributes': {'content': content},
        'relationships': {
          'discussion': {
            'data': {'type': 'discussions', 'id': discussionId},
          },
        },
      },
    });
    return Post.fromJson(doc.data!, doc);
  }

  // ---------------------------------------------------------------------
  // 图片上传（foF Upload 扩展）
  // ---------------------------------------------------------------------

  /// 上传图片，返回可直接插入 markdown 的 URL。
  Future<String> uploadImage(
    String filename,
    List<int> bytes,
  ) async {
    final token = _api.token;
    final req = http.MultipartRequest(
      'POST',
      Uri.parse('${AppConfig.apiUrl}/fof/upload'),
    );
    req.headers['Accept'] = 'application/json';
    if (token != null && token.isNotEmpty) {
      req.headers['Authorization'] = 'Token $token';
    }
    req.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final streamed = await req.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode >= 400) {
      throw ApiException('图片上传失败（HTTP ${res.statusCode}）',
          statusCode: res.statusCode);
    }

    // fof/upload 返回 JSON:API 风格：{"data":{"attributes":{"url":"..."}}}
    // 兼容 {"link":"..."} 等返回格式。
    String? url;
    try {
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      url = json['data']?['attributes']?['url'] as String?;
      url ??= json['link'] as String?;
      url ??= json['data']?['attributes']?['path'] as String?;
    } catch (_) {}
    if (url == null || url.isEmpty) {
      throw ApiException('图片上传成功但未返回地址');
    }
    return url;
  }
}
