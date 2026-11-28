import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/image_utils.dart';
import '../../core/models.dart';
import '../../core/services/forum_service.dart';
import '../../core/utils.dart';
import '../../widgets/user_avatar.dart';

/// 应用内编辑资料：状态、背景图、头像，不跳转论坛网页。
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({Key? key, required this.user}) : super(key: key);

  final ForumUser user;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  late ForumUser _user;
  late final TextEditingController _emojiCtrl;
  late final TextEditingController _statusCtrl;
  bool _savingStatus = false;
  bool _uploadingAvatar = false;
  bool _uploadingCover = false;

  static const List<String> _emojiPresets = [
    '😀', '😄', '😆', '😂', '🤣', '😊', '😍', '😎', '🤔',
    '😅', '😢', '😡', '👍', '👎', '❤️', '🎉', '🔥', '💯',
    '🙏', '🤝', '🚀', '⭐', '☕', '📚', '💪', '🌟',
  ];

  @override
  void initState() {
    super.initState();
    _user = widget.user;
    _emojiCtrl = TextEditingController(text: _user.statusEmoji ?? '');
    _statusCtrl = TextEditingController(text: _user.statusText ?? '');
  }

  @override
  void dispose() {
    _emojiCtrl.dispose();
    _statusCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveStatus() async {
    if (_savingStatus) return;
    setState(() => _savingStatus = true);
    try {
      final emoji = _emojiCtrl.text.trim();
      final text = _statusCtrl.text.trim();
      final updated = await ForumService.instance.updateStatus(
        _user.id,
        emoji: emoji.isEmpty ? null : emoji,
        text: text.isEmpty ? null : text,
      );
      if (!mounted) return;
      setState(() {
        _user = updated;
        _emojiCtrl.text = updated.statusEmoji ?? '';
        _statusCtrl.text = updated.statusText ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('状态已保存')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _savingStatus = false);
    }
  }

  Future<void> _pickAvatar() async {
    if (_uploadingAvatar) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _uploadingAvatar = true);
    try {
      List<int> bytes = await file.readAsBytes();
      String uploadName = file.name;
      if (bytes.length > ImageUtils.maxUploadBytes) {
        bytes = ImageUtils.compress(bytes);
        uploadName = ImageUtils.toJpgName(file.name);
      }
      final updated =
          await ForumService.instance.uploadAvatar(_user.id, uploadName, bytes);
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('头像已更新')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('头像上传失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingAvatar = false);
    }
  }

  Future<void> _pickCover() async {
    if (_uploadingCover) return;
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 900,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _uploadingCover = true);
    try {
      List<int> bytes = await file.readAsBytes();
      String uploadName = file.name;
      if (bytes.length > ImageUtils.maxUploadBytes) {
        bytes = ImageUtils.compress(bytes);
        uploadName = ImageUtils.toJpgName(file.name);
      }
      final updated =
          await ForumService.instance.uploadCover(_user.id, uploadName, bytes);
      if (!mounted) return;
      setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('背景图已更新')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('背景图上传失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  Future<void> _removeCover() async {
    if (_uploadingCover) return;
    setState(() => _uploadingCover = true);
    try {
      await ForumService.instance.deleteCover(_user.id);
      final updated = await ForumService.instance.getUser(_user.id);
      if (!mounted) return;
      if (updated != null) setState(() => _user = updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('背景图已移除')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('移除失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _uploadingCover = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('编辑资料')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildAvatarSection(),
          const SizedBox(height: 16),
          _buildCoverSection(),
          const SizedBox(height: 16),
          _buildStatusSection(),
        ],
      ),
    );
  }

  Widget _sectionCard({required Widget child}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }

  Widget _buildAvatarSection() {
    return _sectionCard(
      child: Row(
        children: [
          UserAvatar(user: _user, radius: 36),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('头像', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: _uploadingAvatar ? null : _pickAvatar,
                  icon: _uploadingAvatar
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('更换头像'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCoverSection() {
    final scheme = Theme.of(context).colorScheme;
    final cover = resolveAssetUrl(_user.cover);

    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('背景图', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          Container(
            height: 120,
            width: double.infinity,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [scheme.primary, scheme.secondary],
              ),
            ),
            child: cover.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: cover,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (_, __, ___) =>
                        const Center(child: Icon(Icons.image_not_supported_outlined)),
                  )
                : Center(
                    child: Icon(Icons.image_outlined, size: 40, color: Colors.white70),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _uploadingCover ? null : _pickCover,
                  icon: _uploadingCover
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.upload_outlined, size: 18),
                  label: Text(_user.cover == null || _user.cover!.isEmpty
                      ? '上传背景图'
                      : '更换背景图'),
                ),
              ),
              if (_user.cover != null && _user.cover!.isNotEmpty) ...[
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _uploadingCover ? null : _removeCover,
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('移除'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusSection() {
    return _sectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('状态', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            '选择一个表情并填写状态文字，会显示在你的个人主页上。',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _emojiCtrl,
            maxLength: 16,
            decoration: const InputDecoration(
              labelText: '状态表情 (Emoji)',
              hintText: '如 😆',
              border: OutlineInputBorder(),
              counterText: '',
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final e in _emojiPresets)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => setState(() => _emojiCtrl.text = e),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.06),
                        ),
                        child: Text(e, style: const TextStyle(fontSize: 22)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _statusCtrl,
            maxLength: 250,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: '状态文字',
              hintText: '最近在做什么？',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _savingStatus ? null : _saveStatus,
              icon: _savingStatus
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check, size: 18),
              label: const Text('保存状态'),
            ),
          ),
          if (_user.statusText != null && _user.statusText!.isNotEmpty) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _savingStatus
                  ? null
                  : () async {
                      _emojiCtrl.clear();
                      _statusCtrl.clear();
                      await _saveStatus();
                    },
              child: const Text('清除状态'),
            ),
          ],
        ],
      ),
    );
  }
}
