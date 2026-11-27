/// 安全地把动态值转为 int（缺失或非数字返回 0）。
int _int(dynamic v) {
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}

/// Flarum JSON:API 文档解析器。
///
/// Flarum 的响应结构为 `{ data, included }`，其中 `included` 存放被引用
/// 的资源（用户、标签、帖子等）。本类把它们按 `type:id` 建索引，方便
/// 通过 relationships 快速取到完整对象。
class ApiDocument {
  ApiDocument(this.raw);

  final Map<String, dynamic> raw;

  Map<String, dynamic>? get data =>
      raw['data'] is Map<String, dynamic> ? raw['data'] as Map<String, dynamic>? : null;

  List<dynamic> get dataList =>
      raw['data'] is List ? (raw['data'] as List) : const [];

  Map<String, dynamic>? get links =>
      raw['links'] is Map<String, dynamic> ? raw['links'] as Map<String, dynamic>? : null;

  /// 下一页地址（page[offset]），不存在表示没有更多。
  String? get nextUrl => links?['next'] as String?;

  /// 错误信息（Flarum 返回 { errors: [{ code, detail }] }）。
  String? get error {
    final errs = raw['errors'];
    if (errs is List && errs.isNotEmpty) {
      final first = errs.first;
      if (first is Map) {
        return first['detail']?.toString() ?? first['code']?.toString();
      }
    }
    return null;
  }

  final Map<String, Map<String, dynamic>> _included = {};

  /// 建立 included 索引。
  void indexIncluded() {
    final inc = raw['included'];
    if (inc is List) {
      for (final item in inc) {
        if (item is Map) {
          final type = item['type']?.toString();
          final id = item['id']?.toString();
          if (type != null && id != null) {
            _included['$type:$id'] = Map<String, dynamic>.from(item);
          }
        }
      }
    }
  }

  /// 根据 relationship 引用取 included 对象。
  Map<String, dynamic>? ref(dynamic rel) {
    if (rel is! Map) return null;
    final data = rel['data'];
    if (data is Map) {
      final type = data['type']?.toString();
      final id = data['id']?.toString();
      if (type == null || id == null) return null;
      final indexed = _included['$type:$id'];
      if (indexed != null) return indexed;
      return Map<String, dynamic>.from(data);
    }
    return null;
  }
}

/// 用户
class ForumUser {
  ForumUser.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString() ?? '',
        attributes = (json['attributes'] ?? const {}) as Map;

  final String id;
  final Map attributes;

  String get username => (attributes['username'] ?? '').toString();
  String get displayName =>
      (attributes['displayName'] ?? attributes['username'] ?? '').toString();

  /// 头像地址，Flarum 返回的可能是相对路径。
  String? get avatarUrl => attributes['avatarUrl'] as String?;

  String? get bio => attributes['bio'] as String?;
  int get discussionCount => _int(attributes['discussionCount']);
  int get commentCount => _int(attributes['commentCount']);
  String? get joinTime => attributes['joinTime'] as String?;
  String? get lastSeenAt => attributes['lastSeenAt'] as String?;
  int? get points {
    final v = attributes['points'] ?? attributes['moneoPoints'];
    return v is num ? v.toInt() : null;
  }

  /// 是否管理员/版主（Flarum 用 canEdit 等布尔，或昵称颜色标记）。
  bool get isAdmin => (attributes['isAdmin'] ?? false) == true;
}

/// 标签（板块）
class Tag {
  Tag.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString() ?? '',
        attributes = (json['attributes'] ?? const {}) as Map,
        parentId = _parentId(json);

  final String id;
  final Map attributes;
  final String? parentId;

  static String? _parentId(Map<String, dynamic> json) {
    final rel = json['relationships'];
    if (rel is Map) {
      final parent = rel['parent'];
      if (parent is Map) {
        final data = parent['data'];
        if (data is Map) return data['id']?.toString();
      }
    }
    return null;
  }

  String get name => (attributes['name'] ?? '').toString();
  String get slug => (attributes['slug'] ?? '').toString();
  String get description => (attributes['description'] ?? '').toString();

  /// 颜色（十六进制，如 #00bfff）。
  String? get color => attributes['color'] as String?;
  String get icon => (attributes['icon'] ?? '').toString();
  int get discussionCount => _int(attributes['discussionCount']);
  bool get isChild => (attributes['isChild'] ?? false) == true;
  bool get isHidden => (attributes['isHidden'] ?? false) == true;
  String? get lastPostedAt => attributes['lastPostedAt'] as String?;

  /// 将 #rrggbb 转为 Color。
  static int? parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    var h = hex.replaceAll('#', '');
    if (h.length == 3) {
      h = h.split('').map((c) => '$c$c').join();
    }
    if (h.length != 6) return null;
    return int.tryParse('FF$h', radix: 16);
  }
}

/// 表情回应（fof/reactions）。
class Reaction {
  Reaction.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString() ?? '',
        attributes = (json['attributes'] ?? const {}) as Map;

  final String id;
  final Map attributes;

  /// 英文标识，如 thumbsup / laughing / heart。
  String get identifier => (attributes['identifier'] ?? '').toString();

  /// 类型（emoji 等）。
  String get type => (attributes['type'] ?? '').toString();

  bool get enabled => (attributes['enabled'] ?? false) == true;

  /// 将 identifier 映射为可显示的 Emoji。
  String get emoji {
    switch (identifier) {
      case 'thumbsup':
        return '👍';
      case 'thumbsdown':
        return '👎';
      case 'laughing':
        return '😄';
      case 'confused':
        return '😕';
      case 'heart':
        return '❤️';
      case 'tada':
        return '🎉';
      case 'cold_sweat':
        return '😅';
      case 'joy':
        return '😂';
      case 'angry':
        return '😡';
      case 'cry':
        return '😢';
      default:
        return '😀';
    }
  }
}

/// 讨论（帖子主题）
class Discussion {
  Discussion.fromJson(Map<String, dynamic> json, ApiDocument doc)
      : id = json['id']?.toString() ?? '',
        attributes = (json['attributes'] ?? const {}) as Map,
        _doc = doc,
        _json = json;

  final String id;
  final Map attributes;
  final ApiDocument _doc;
  final Map<String, dynamic> _json;

  String get title => (attributes['title'] ?? '').toString();
  String get slug => (attributes['slug'] ?? '').toString();
  int get commentCount => _int(attributes['commentCount']);
  int get participantCount => _int(attributes['participantCount']);
  String? get createdAt => attributes['createdAt'] as String?;
  String? get lastPostedAt => attributes['lastPostedAt'] as String?;
  int get lastPostNumber {
    final v = attributes['lastPostNumber'];
    return v is num ? v.toInt() : 0;
  }

  int get views => _int(attributes['views']);
  bool get isSticky => (attributes['isSticky'] ?? false) == true;
  bool get isStickiest => (attributes['isStickiest'] ?? false) == true;
  bool get isTagSticky => (attributes['isTagSticky'] ?? false) == true;
  bool get hasBestAnswer => (attributes['hasBestAnswer'] ?? false) == true;
  bool get isLocked => (attributes['isLocked'] ?? false) == true;
  bool get canReply => (attributes['canReply'] ?? false) == true;
  String get shareUrl =>
      (attributes['shareUrl'] ?? '${_docUrl()}/d/$id').toString();

  String _docUrl() {
    // 从 links 或 baseUrl 推导，这里直接用站点配置。
    return 'https://forum.smart-teach.cn';
  }

  ForumUser? get author {
    final rel = _json['relationships'];
    if (rel is Map) {
      final u = _doc.ref(rel['user']);
      if (u != null) return ForumUser.fromJson(u);
    }
    return null;
  }

  ForumUser? get lastPostedUser {
    final rel = _json['relationships'];
    if (rel is Map) {
      final u = _doc.ref(rel['lastPostedUser']);
      if (u != null) return ForumUser.fromJson(u);
    }
    return null;
  }

  /// 首帖（用于列表页摘要）。
  Post? get firstPost {
    final rel = _json['relationships'];
    if (rel is Map) {
      final p = _doc.ref(rel['firstPost']);
      if (p != null) return Post.fromJson(p, _doc);
    }
    return null;
  }

  List<Tag> get tags {
    final rel = _json['relationships'];
    final list = <Tag>[];
    if (rel is Map) {
      final tagsRel = rel['tags'];
      if (tagsRel is Map && tagsRel['data'] is List) {
        for (final t in (tagsRel['data'] as List)) {
          final full = _doc.ref(t);
          if (full != null) list.add(Tag.fromJson(full));
        }
      }
    }
    return list;
  }
}

/// 帖子（楼层回复）
class Post {
  Post.fromJson(Map<String, dynamic> json, ApiDocument doc)
      : id = json['id']?.toString() ?? '',
        attributes = (json['attributes'] ?? const {}) as Map,
        _doc = doc,
        _json = json;

  final String id;
  final Map attributes;
  final ApiDocument _doc;
  final Map<String, dynamic> _json;

  int? get number {
    final v = attributes['number'];
    return v is num ? v.toInt() : null;
  }
  String get contentHtml => (attributes['contentHtml'] ?? '').toString();
  String get content =>
      (attributes['content'] ?? attributes['contentHtml'] ?? '').toString();
  String? get createdAt => attributes['createdAt'] as String?;
  String? get editedAt => attributes['editedAt'] as String?;
  bool? get canEdit => (attributes['canEdit'] ?? false) == true;
  bool? get canDelete => (attributes['canDelete'] ?? false) == true;

  /// 点赞数（若站点启用 likes 扩展）。
  int? get likesCount {
    final rel = _json['relationships'];
    if (rel is Map) {
      final likes = rel['likes'];
      if (likes is Map && likes['data'] is List) {
        return (likes['data'] as List).length;
      }
    }
    return null;
  }

  /// 净赞数（fof/gamification 的 votes 字段，登录态返回字符串数字）。
  int get votes => _int(attributes['votes']);

  /// 当前用户是否已点赞。
  bool get hasUpvoted => (attributes['hasUpvoted'] ?? false) == true;

  /// 当前用户是否已踩。
  bool get hasDownvoted => (attributes['hasDownvoted'] ?? false) == true;

  /// 当前用户是否可以投票（赞/踩）。
  bool get canVote => (attributes['canVote'] ?? false) == true;

  /// 当前用户是否可以查看投票者。
  bool get canSeeVotes => (attributes['canSeeVotes'] ?? false) == true;

  /// 当前用户是否可以发表情回应（fof/reactions）。
  bool get canReact => (attributes['canReact'] ?? false) == true;

  /// 各表情的计数，如 {"1": 15, "6": 9}。
  Map<String, int> get reactionCounts {
    final v = attributes['reactionCounts'];
    if (v is! Map) return const {};
    final out = <String, int>{};
    v.forEach((k, val) => out[k.toString()] = _int(val));
    return out;
  }

  /// 当前用户所选表情的 reaction id（无则为 null）。
  String? get userReactionIdentifier =>
      attributes['userReactionIdentifier']?.toString();

  ForumUser? get author {
    final rel = _json['relationships'];
    if (rel is Map) {
      final u = _doc.ref(rel['user']);
      if (u != null) return ForumUser.fromJson(u);
    }
    return null;
  }

  List<Post> get mentionedBy {
    final rel = _json['relationships'];
    final list = <Post>[];
    if (rel is Map) {
      final m = rel['mentionedBy'];
      if (m is Map && m['data'] is List) {
        for (final p in (m['data'] as List)) {
          final full = _doc.ref(p);
          if (full != null) list.add(Post.fromJson(full, _doc));
        }
      }
    }
    return list;
  }
}

/// 通知
class NotificationItem {
  NotificationItem.fromJson(Map<String, dynamic> json)
      : id = json['id']?.toString() ?? '',
        attributes = (json['attributes'] ?? const {}) as Map;

  final String id;
  final Map attributes;

  String get type => (attributes['contentType'] ?? '').toString();
  String get contentHtml => (attributes['contentHtml'] ?? '').toString();
  String? get createdAt => attributes['createdAt'] as String?;
  bool get isRead => (attributes['isRead'] ?? false) == true;

  /// 通知类型的中文友好名。
  String get typeLabel {
    switch (type) {
      case 'discussionRenamed':
        return '标题修改';
      case 'postMentioned':
        return '提及';
      case 'userMentioned':
        return '提及';
      case 'postLiked':
        return '点赞';
      case 'postReacted':
        return '回应';
      case 'newPost':
        return '回复';
      case 'discussionLocked':
        return '锁定';
      case 'discussionStickied':
        return '置顶';
      default:
        return type;
    }
  }
}
