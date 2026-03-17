import 'package:flutter_test/flutter_test.dart';
import 'package:color_pop/features/editor/editor_provider.dart';
import 'package:color_pop/models/brush_settings.dart';
import 'package:color_pop/models/detected_object.dart';
import 'package:color_pop/models/ai_suggestion.dart';
import 'package:color_pop/models/color_selection.dart';
import 'package:color_pop/models/effect_config.dart';

void main() {
  group('EditorState', () {
    test('기본 초기 상태 검증', () {
      const state = EditorState();
      expect(state.status, EditorStatus.idle);
      expect(state.mode, EditorMode.brush);
      expect(state.canUndo, false);
      expect(state.canRedo, false);
      expect(state.imageWidth, 0);
      expect(state.imageHeight, 0);
    });

    test('copyWith - 상태 변경', () {
      const initial = EditorState();
      final updated = initial.copyWith(
        status: EditorStatus.ready,
        imageWidth: 1080,
        imageHeight: 1920,
        canUndo: true,
      );
      expect(updated.status, EditorStatus.ready);
      expect(updated.imageWidth, 1080);
      expect(updated.imageHeight, 1920);
      expect(updated.canUndo, true);
      expect(updated.canRedo, false); // 변경되지 않음
    });

    test('copyWith - error는 null로 명시적 설정 가능', () {
      const state = EditorState();
      final withError = state.copyWith(error: '테스트 오류');
      expect(withError.error, '테스트 오류');

      final cleared = withError.copyWith(error: null);
      expect(cleared.error, isNull);
    });

    test('브러시 설정 변경', () {
      const state = EditorState();
      const newBrush = BrushSettings(size: 80, mode: BrushMode.erase);
      final updated = state.copyWith(brushSettings: newBrush);
      expect(updated.brushSettings.size, 80);
      expect(updated.brushSettings.mode, BrushMode.erase);
    });
  });

  // ── Phase 3: AI 필드 테스트 ─────────────────────────────────
  group('EditorState AI 필드', () {
    const personObj = DetectedObject(
      label: 'person', korLabel: '인물', confidence: 0.98,
      x: 0.1, y: 0.2, w: 0.4, h: 0.6, maskType: 'person',
    );
    const suggestion = AiSuggestion(
      id: 'suggest_person', title: '인물 컬러 살리기',
      description: '인물만 컬러로', maskLabel: 'person', colorHex: '#FF6B9D',
    );

    test('초기 AI 상태 기본값 검증', () {
      const state = EditorState();
      expect(state.detectedObjects, isEmpty);
      expect(state.aiSuggestions, isEmpty);
      expect(state.selectedObject, isNull);
      expect(state.isAiAnalyzing, false);
      expect(state.isAiApplying, false);
    });

    test('copyWith - detectedObjects 업데이트', () {
      const state = EditorState();
      final updated = state.copyWith(detectedObjects: [personObj]);
      expect(updated.detectedObjects.length, 1);
      expect(updated.detectedObjects.first.label, 'person');
    });

    test('copyWith - aiSuggestions 업데이트', () {
      const state = EditorState();
      final updated = state.copyWith(aiSuggestions: [suggestion]);
      expect(updated.aiSuggestions.length, 1);
      expect(updated.aiSuggestions.first.id, 'suggest_person');
    });

    test('copyWith - isAiAnalyzing 플래그 토글', () {
      const state = EditorState();
      final analyzing = state.copyWith(isAiAnalyzing: true);
      expect(analyzing.isAiAnalyzing, true);
      final done = analyzing.copyWith(isAiAnalyzing: false);
      expect(done.isAiAnalyzing, false);
    });

    test('copyWith - selectedObject 설정 및 clearSelectedObject', () {
      const state = EditorState();
      final selected = state.copyWith(selectedObject: personObj);
      expect(selected.selectedObject?.label, 'person');

      final cleared = selected.copyWith(clearSelectedObject: true);
      expect(cleared.selectedObject, isNull);
    });

    test('copyWith - isAiApplying 플래그', () {
      const state = EditorState();
      final applying = state.copyWith(isAiApplying: true, selectedObject: personObj);
      expect(applying.isAiApplying, true);
      expect(applying.selectedObject?.label, 'person');
    });
  });

  // ── Phase 4: 색상 선택 필드 테스트 ──────────────────────────
  group('EditorState 색상 선택 필드', () {
    const redSel = ColorSelection(
      h: 0.0, s: 1.0, l: 0.5, hexColor: '#FF0000',
    );
    const blueSel = ColorSelection(
      h: 0.67, s: 1.0, l: 0.5, hexColor: '#0000FF',
    );

    test('초기 색상 상태 기본값 검증', () {
      const state = EditorState();
      expect(state.colorSelection, isNull);
      expect(state.colorRangeEndSelection, isNull);
      expect(state.isColorRangeMode, false);
      expect(state.isColorApplying, false);
    });

    test('copyWith - colorSelection 설정', () {
      const state = EditorState();
      final updated = state.copyWith(colorSelection: redSel);
      expect(updated.colorSelection?.hexColor, '#FF0000');
    });

    test('copyWith - clearColorSelection=true → null', () {
      const state = EditorState();
      final withColor = state.copyWith(colorSelection: redSel);
      final cleared = withColor.copyWith(clearColorSelection: true);
      expect(cleared.colorSelection, isNull);
    });

    test('copyWith - colorRangeEndSelection 설정', () {
      const state = EditorState();
      final updated = state.copyWith(
        colorSelection: redSel,
        colorRangeEndSelection: blueSel,
      );
      expect(updated.colorRangeEndSelection?.hexColor, '#0000FF');
    });

    test('copyWith - clearColorRangeEnd=true → rangeEnd null 유지', () {
      const state = EditorState();
      final withRange = state.copyWith(
        colorSelection: redSel,
        colorRangeEndSelection: blueSel,
      );
      final cleared = withRange.copyWith(clearColorRangeEnd: true);
      expect(cleared.colorRangeEndSelection, isNull);
      expect(cleared.colorSelection?.hexColor, '#FF0000'); // 시작 색상 유지
    });

    test('copyWith - isColorRangeMode 토글', () {
      const state = EditorState();
      final rangeOn = state.copyWith(isColorRangeMode: true);
      expect(rangeOn.isColorRangeMode, true);
      final rangeOff = rangeOn.copyWith(isColorRangeMode: false);
      expect(rangeOff.isColorRangeMode, false);
    });

    test('copyWith - isColorApplying 플래그', () {
      const state = EditorState();
      final applying = state.copyWith(isColorApplying: true);
      expect(applying.isColorApplying, true);
      final done = applying.copyWith(isColorApplying: false);
      expect(done.isColorApplying, false);
    });

    test('색상 선택 후 tolerance 업데이트 시 h/s 유지', () {
      const state = EditorState();
      final withColor = state.copyWith(colorSelection: redSel);
      final newTol = ColorSelection.toleranceFromPercent(50);
      final updated = withColor.colorSelection!.copyWith(tolerance: newTol);
      final newState = withColor.copyWith(colorSelection: updated);
      expect(newState.colorSelection?.h, redSel.h);
      expect(newState.colorSelection?.s, redSel.s);
      expect(newState.colorSelection?.tolerance, closeTo(0.25, 0.001));
    });
  });

  // ── Phase 5: 이펙트 필드 테스트 ──────────────────────────────
  group('EditorState 이펙트 필드', () {
    test('초기 이펙트 상태 기본값 검증', () {
      const state = EditorState();
      expect(state.effectConfig.type, EffectType.none);
      expect(state.effectConfig.intensity, 0.5);
      expect(state.isInverseMode, false);
    });

    test('copyWith - effectConfig 변경', () {
      const state = EditorState();
      final newConfig = EffectConfig(type: EffectType.neonGlow, intensity: 0.8);
      final updated = state.copyWith(effectConfig: newConfig);
      expect(updated.effectConfig.type, EffectType.neonGlow);
      expect(updated.effectConfig.intensity, closeTo(0.8, 0.001));
    });

    test('copyWith - isInverseMode 토글', () {
      const state = EditorState();
      final inverted = state.copyWith(isInverseMode: true);
      expect(inverted.isInverseMode, true);
      final normal = inverted.copyWith(isInverseMode: false);
      expect(normal.isInverseMode, false);
    });

    test('copyWith - effectConfig.type 변경 시 intensity 유지', () {
      const state = EditorState();
      final withEffect = state.copyWith(
        effectConfig: const EffectConfig(type: EffectType.chromatic, intensity: 0.6),
      );
      final typeChanged = withEffect.copyWith(
        effectConfig: withEffect.effectConfig.copyWith(type: EffectType.filmNoir),
      );
      expect(typeChanged.effectConfig.type, EffectType.filmNoir);
      expect(typeChanged.effectConfig.intensity, closeTo(0.6, 0.001));
    });

    test('모든 EffectType 값을 effectConfig에 설정할 수 있다', () {
      for (final t in EffectType.values) {
        final state = EditorState();
        final updated = state.copyWith(
          effectConfig: EffectConfig(type: t, intensity: 0.5),
        );
        expect(updated.effectConfig.type, t);
      }
    });

    test('isInverseMode는 다른 필드 변경에 영향받지 않는다', () {
      const state = EditorState();
      final withInverse = state.copyWith(isInverseMode: true);
      final withStatus = withInverse.copyWith(status: EditorStatus.ready);
      expect(withStatus.isInverseMode, true);
    });
  });

  group('EditorMode', () {
    test('모든 모드 값이 정의되어 있다', () {
      expect(EditorMode.values.length, 4);
      expect(EditorMode.values, containsAll([
        EditorMode.brush,
        EditorMode.colorSelect,
        EditorMode.aiObject,
        EditorMode.effects,
      ]));
    });
  });

  group('EditorStatus', () {
    test('모든 상태 값이 정의되어 있다', () {
      expect(EditorStatus.values, containsAll([
        EditorStatus.idle,
        EditorStatus.loading,
        EditorStatus.ready,
        EditorStatus.error,
      ]));
    });
  });
}
