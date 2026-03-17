import 'dart:convert';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../../models/edit_item.dart';

// ── 상태 정의 ──────────────────────────────────────────────────
class HomeState {
  final List<EditItem> recentItems;
  final bool isLoading;
  final String? error;

  const HomeState({
    this.recentItems = const [],
    this.isLoading = false,
    this.error,
  });

  HomeState copyWith({
    List<EditItem>? recentItems,
    bool? isLoading,
    String? error,
  }) {
    return HomeState(
      recentItems: recentItems ?? this.recentItems,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Notifier ───────────────────────────────────────────────────
class HomeNotifier extends StateNotifier<HomeState> {
  HomeNotifier() : super(const HomeState()) {
    _loadRecentItems();
  }

  static const _prefKey = 'recent_edit_items';
  final _picker = ImagePicker();

  // 저장된 최근 편집 목록 로드
  Future<void> _loadRecentItems() async {
    state = state.copyWith(isLoading: true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = prefs.getStringList(_prefKey) ?? [];
      final items = jsonList
          .map((json) => EditItem.fromJson(jsonDecode(json) as Map<String, dynamic>))
          .where((item) => File(item.imagePath).existsSync()) // 삭제된 파일 필터
          .toList();
      state = state.copyWith(recentItems: items, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: '불러오기 실패');
    }
  }

  // 갤러리에서 이미지 선택
  Future<EditItem?> pickFromGallery() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
      );
      if (xFile == null) return null;
      return await _saveAndCreateItem(xFile.path);
    } catch (_) {
      state = state.copyWith(error: '갤러리 접근 실패');
      return null;
    }
  }

  // 카메라로 촬영 (Phase 6에서 고도화, 현재는 기본 카메라 연동)
  Future<EditItem?> pickFromCamera() async {
    try {
      final xFile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 100,
      );
      if (xFile == null) return null;
      return await _saveAndCreateItem(xFile.path);
    } catch (_) {
      state = state.copyWith(error: '카메라 접근 실패');
      return null;
    }
  }

  // 앱 내부 저장소에 이미지 복사 후 EditItem 생성
  Future<EditItem> _saveAndCreateItem(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final destPath = p.join(dir.path, 'color_pop_$id.jpg');
    await File(sourcePath).copy(destPath);

    final item = EditItem(
      id: id,
      imagePath: destPath,
      createdAt: DateTime.now(),
    );

    final updated = [item, ...state.recentItems];
    state = state.copyWith(recentItems: updated);
    await _persistItems(updated);
    return item;
  }

  // 아이템 삭제
  Future<void> deleteItem(String id) async {
    final item = state.recentItems.firstWhere((e) => e.id == id);
    final file = File(item.imagePath);
    if (await file.exists()) await file.delete();

    final updated = state.recentItems.where((e) => e.id != id).toList();
    state = state.copyWith(recentItems: updated);
    await _persistItems(updated);
  }

  // SharedPreferences 저장
  Future<void> _persistItems(List<EditItem> items) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = items.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_prefKey, jsonList);
  }
}

// ── Provider ───────────────────────────────────────────────────
final homeProvider = StateNotifierProvider<HomeNotifier, HomeState>(
  (_) => HomeNotifier(),
);
