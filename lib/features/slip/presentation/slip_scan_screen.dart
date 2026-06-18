import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../bootstrap/providers.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/bun_avatar.dart';
import '../../../core/widgets/pixel_border.dart';
import '../../../core/widgets/pixel_button.dart';
import '../data/slip_importer.dart';

class SlipScanScreen extends ConsumerStatefulWidget {
  const SlipScanScreen({super.key});

  @override
  ConsumerState<SlipScanScreen> createState() => _SlipScanScreenState();
}

class _SlipScanScreenState extends ConsumerState<SlipScanScreen> {
  bool _busy = false;
  String _status = '';
  int? _imported;
  List<SlipAlbum>? _albums;

  SlipImporter get _importer => ref.read(slipImporterProvider);

  Future<void> _chooseAlbum() async {
    setState(() {
      _busy = true;
      _status = 'กำลังขอสิทธิ์เข้าถึงรูป...';
    });
    final ok = await _importer.ensurePermission();
    if (!ok) {
      _snack('ไม่ได้รับสิทธิ์เข้าถึงรูปในเครื่อง');
      setState(() => _busy = false);
      return;
    }
    final albums = await _importer.listAlbums();
    setState(() {
      _busy = false;
      _albums = albums;
    });
  }

  Future<void> _runAlbum(SlipAlbum album) async {
    ref.read(selectedAlbumProvider.notifier).set(album.id);
    setState(() => _albums = null);
    await _run('กำลังอ่านสลิปจาก "${album.name}"...',
        () => _importer.importFromAlbum(album.id));
  }

  Future<void> _run(String status, Future<int> Function() task) async {
    setState(() {
      _busy = true;
      _status = status;
      _imported = null;
    });
    try {
      final n = await task();
      setState(() => _imported = n);
    } catch (e) {
      _snack('$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('สแกนสลิป')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _busy
            ? _busyView()
            : _imported != null
                ? _resultView()
                : _albums != null
                    ? _albumPicker()
                    : _intro(),
      ),
    );
  }

  Widget _intro() {
    return Column(
      children: [
        const SizedBox(height: 8),
        const BunAvatar(size: 88, mood: BunMood.happy),
        const SizedBox(height: 12),
        const Text('ให้น้องบันอ่านสลิปให้',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
        const SizedBox(height: 4),
        const Text(
          'อ่านสลิปธนาคารไทย/ทรูมันนี่จากรูปในเครื่อง แล้วเก็บไว้ให้เลือกหมวดหมู่',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.gray500),
        ),
        const SizedBox(height: 28),
        PixelButton(
          label: 'สแกนจากอัลบั้มในเครื่อง',
          icon: Icons.photo_album,
          expand: true,
          onPressed: _chooseAlbum,
        ),
      ],
    );
  }

  Widget _albumPicker() {
    final albums = _albums!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('เลือกอัลบั้มที่เก็บสลิป',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.separated(
            itemCount: albums.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) {
              final a = albums[i];
              return PixelBorder(
                onTap: () => _runAlbum(a),
                child: Row(
                  children: [
                    const Icon(Icons.photo_album, color: AppColors.bunOrange),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(a.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    Text('${a.count} รูป',
                        style: const TextStyle(color: AppColors.gray500)),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _busyView() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const BunAvatar(size: 72),
            const SizedBox(height: 16),
            const CircularProgressIndicator(),
            const SizedBox(height: 12),
            Text(_status, textAlign: TextAlign.center),
          ],
        ),
      );

  Widget _resultView() {
    final n = _imported!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          BunAvatar(size: 88, mood: n > 0 ? BunMood.happy : BunMood.sleepy),
          const SizedBox(height: 16),
          Text(n > 0 ? 'นำเข้า $n สลิป' : 'ไม่พบสลิปใหม่',
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 6),
          const Text('ไปหน้าหลักเพื่อเลือกหมวดหมู่ของแต่ละสลิป',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.gray500)),
          const SizedBox(height: 24),
          PixelButton(
            label: 'ไปหน้าหลัก',
            icon: Icons.home_rounded,
            onPressed: () => context.go('/home'),
          ),
        ],
      ),
    );
  }
}
