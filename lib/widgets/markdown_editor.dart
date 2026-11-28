import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';

import '../core/services/forum_service.dart';

/// Markdown 编辑器：带格式化工具栏 + 图片上传。
class MarkdownEditor extends StatefulWidget {
  const MarkdownEditor({
    Key? key,
    required this.controller,
    this.hint = '输入内容…',
    this.minLines = 8,
    this.maxLines = 20,
  }) : super(key: key);

  final TextEditingController controller;
  final String hint;
  final int minLines;
  final int maxLines;

  @override
  State<MarkdownEditor> createState() => _MarkdownEditorState();
}

class _MarkdownEditorState extends State<MarkdownEditor> {
  bool _uploading = false;

  TextEditingController get _ctrl => widget.controller;

  void _wrap(String prefix, String suffix, {String placeholder = '文字'}) {
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final selected = text.substring(start, end);

    final inner = selected.isEmpty ? placeholder : selected;
    final replacement = '$prefix$inner$suffix';

    final newText = text.replaceRange(start, end, replacement);
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: selected.isEmpty ? start + prefix.length : start + replacement.length,
      ),
    );
  }

  void _insertLine(String prefix) {
    final text = _ctrl.text;
    final sel = _ctrl.selection;
    final start = sel.isValid ? sel.start : text.length;
    // 在行首插入
    final lineStart = text.lastIndexOf('\n', start - 1) + 1;
    final newText = text.replaceRange(lineStart, lineStart, prefix);
    _ctrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + prefix.length),
    );
  }

  /// 上传大小安全阈值（1.2MB）。论坛 fof/upload 对超大文件会在 PHP 层直接
  /// 丢弃并提示「请上传小于 xx KB 的文件」，因此这里强制压缩到阈值以内。
  static const int _maxUploadBytes = 1200 * 1024;

  Future<void> _pickAndUpload() async {
    if (_uploading) return;
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );
    } catch (_) {
      file = null;
    }
    if (file == null) return;

    setState(() => _uploading = true);
    try {
      List<int> bytes = await file.readAsBytes();
      bytes = await _compressIfNeeded(bytes);
      final url = await ForumService.instance.uploadImage(file.name, bytes);
      if (!mounted) return;
      _wrap('![图片](', ')', placeholder: url);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片已上传并插入')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('图片上传失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  /// 若图片仍超过安全阈值，解码后重新编码为 JPEG 并逐步降质，确保足够小。
  Future<List<int>> _compressIfNeeded(List<int> bytes) async {
    if (bytes.length <= _maxUploadBytes) return bytes;

    try {
      img.Image? decoded = img.decodeImage(bytes);
      if (decoded == null) return bytes;

      // 先按宽高缩放到最长边 1440。
      if (decoded.width > 1440 || decoded.height > 1440) {
        decoded = img.copyResize(
          decoded,
          width: decoded.width >= decoded.height ? 1440 : null,
          height: decoded.height > decoded.width ? 1440 : null,
        );
      }

      // 逐步降低 JPEG 质量，直到满足阈值。
      for (final quality in const [80, 70, 60, 50, 40]) {
        final jpg = img.encodeJpg(decoded, quality: quality);
        if (jpg.length <= _maxUploadBytes) return jpg;
      }
      // 最后兜底：最低质量仍超限则返回最小体积的编码。
      return img.encodeJpg(decoded, quality: 30);
    } catch (_) {
      return bytes;
    }
  }

  Future<void> _insertImageUrl() async {
    final urlCtrl = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('插入图片链接'),
        content: TextField(
          controller: urlCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'https://…'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, urlCtrl.text.trim()),
            child: const Text('插入'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      _wrap('![图片](', ')', placeholder: result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildToolbar(),
        const SizedBox(height: 4),
        TextField(
          controller: _ctrl,
          minLines: widget.minLines,
          maxLines: widget.maxLines,
          keyboardType: TextInputType.multiline,
          decoration: InputDecoration(
            hintText: widget.hint,
            border: const OutlineInputBorder(),
            contentPadding: const EdgeInsets.all(12),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '支持 Markdown 语法：**粗体**、*斜体*、~~删除线~~、`代码`、> 引用、[链接](url)、![图片](url)',
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildToolbar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _toolButton(Icons.format_bold, '粗体', () => _wrap('**', '**')),
          _toolButton(Icons.format_italic, '斜体', () => _wrap('*', '*')),
          _toolButton(Icons.strikethrough_s, '删除线', () => _wrap('~~', '~~')),
          _toolButton(Icons.code, '代码', () => _wrap('`', '`', placeholder: '代码')),
          _toolButton(Icons.format_quote, '引用', () => _insertLine('> ')),
          _toolButton(Icons.link, '链接', () => _wrap('[', '](https://)', placeholder: '文字')),
          _toolButton(Icons.image_outlined, '上传图片', _pickAndUpload),
          _toolButton(Icons.add_link, '图片外链', _insertImageUrl),
          if (_uploading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
    );
  }

  Widget _toolButton(IconData icon, String label, VoidCallback onPressed) {
    return Tooltip(
      message: label,
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
