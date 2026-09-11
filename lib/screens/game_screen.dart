import 'dart:math';

import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

import '../game/managers/settings_manager.dart';
import '../game/managers/storage_manager.dart';
import 'overlays/level_complete_overlay.dart';
import 'overlays/level_failed_overlay.dart';
import 'overlays/pause_overlay.dart';

class _CubeColorInfo {
  const _CubeColorInfo(this.color, this.label);
  final Color color;
  final String label;
}

const List<_CubeColorInfo> _palette = [
  _CubeColorInfo(Color(0xFFE74C3C), 'Kırmızı'),
  _CubeColorInfo(Color(0xFF3498DB), 'Mavi'),
  _CubeColorInfo(Color(0xFF2ECC71), 'Yeşil'),
  _CubeColorInfo(Color(0xFFF1C40F), 'Sarı'),
  _CubeColorInfo(Color(0xFF9B59B6), 'Mor'),
  _CubeColorInfo(Color(0xFF1ABC9C), 'Turkuaz'),
];

class _Cube {
  _Cube({
    required this.layer,
    required this.row,
    required this.col,
    required this.color,
  });
  final int layer;
  final int row;
  final int col;
  Color color;
  bool removed = false;
}

class _Mission {
  _Mission({required this.color, required this.label, required this.target});
  final Color color;
  final String label;
  final int target;
  int progress = 0;
  bool get isComplete => progress >= target;
}

enum _Status { playing, paused, levelComplete, levelFailed }

/// Bir küpün üç yüzünün (üst/sol/sağ) çizim yollarını hesaplar.
/// Hem çizim hem de isabet testi (hit-test) için ORTAK kullanılır ki
/// "göze göründüğü yer" ile "dokununca algılanan yer" HER ZAMAN aynı olsun.
class _CubeFaces {
  _CubeFaces(Offset anchor, double tileWidth, double tileHeight, double cubeDepth) {
    final cx = anchor.dx;
    final cy = anchor.dy;
    final hw = tileWidth / 2;
    final hh = tileHeight / 2;

    top = Offset(cx, cy - hh);
    right = Offset(cx + hw, cy);
    bottom = Offset(cx, cy + hh);
    left = Offset(cx - hw, cy);

    topFace = Path()
      ..moveTo(top.dx, top.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(left.dx, left.dy)
      ..close();

    leftFace = Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(bottom.dx, bottom.dy)
      ..lineTo(bottom.dx, bottom.dy + cubeDepth)
      ..lineTo(left.dx, left.dy + cubeDepth)
      ..close();

    rightFace = Path()
      ..moveTo(bottom.dx, bottom.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(right.dx, right.dy + cubeDepth)
      ..lineTo(bottom.dx, bottom.dy + cubeDepth)
      ..close();
  }

  late Offset top, right, bottom, left;
  late Path topFace, leftFace, rightFace;

  bool contains(Offset point) =>
      topFace.contains(point) || leftFace.contains(point) || rightFace.contains(point);
}

/// Blok toplama bulmacası: izometrik piramit şeklinde dizilmiş renkli
/// küpler. Bir küp ancak üzerinde başka küp kalmadıysa toplanabilir.
/// Görevler üstte gösterilir; hepsi tamamlanınca seviye biter. Görev
/// rengi olmayan "yanlış" küpler sınırlı sayıda kaldırılabilir.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  static const double _tileWidth = 44;
  static const double _tileHeight = 22;
  static const double _cubeDepth = 36;

  final Random _random = Random();

  int _level = 1;
  int _numLayers = 2; // piramitteki katman sayısı
  int _bottomSize = 3; // en alt katmanın boyutu (bottomSize x bottomSize)
  late List<List<List<_Cube?>>> _grid; // _grid[layer][localRow][localCol]
  late List<_Cube> _allCubes;
  late List<_Mission> _missions;
  late Set<Color> _decoyColors;

  final List<_Cube> _removalHistory = [];

  int _undoCount = 3;
  int _shuffleCount = 3;
  int _bombCount = 3;
  bool _bombArmed = false;

  int _mistakesAllowed = 5;
  int _mistakesUsed = 0;

  int _bestLevel = 1;

  _Status _status = _Status.playing;

  // Piramidi sağa-sola sürükleyerek döndürme.
  double _theta = 0;
  Offset _dragStart = Offset.zero;
  double _dragTotalMovement = 0;
  bool _isDragRotating = false;
  static const double _rotationDragThreshold = 6;
  static const double _rotationSpeed = 0.008;

  @override
  void initState() {
    super.initState();
    _bestLevel = StorageManager.instance.highScore;
    if (_bestLevel < 1) _bestLevel = 1;
    _level = _bestLevel;
    _generateLevel();
  }

  void _generateLevel() {
    // Katman sayısı arttıkça piramit büyür. Her katman bir alttakinden
    // TAM 2 birim küçük (her kenarda 1 birim payanda) - bu sayede her
    // küp doğrudan altındaki TEK küpün üstüne oturur, katmanlar asla
    // birbirinin içine geçmez / karışmaz.
    _numLayers = (1 + _level).clamp(2, 4);
    _bottomSize = 2 * _numLayers - 1;

    final shuffledPalette = List<_CubeColorInfo>.from(_palette)..shuffle(_random);
    final missionCount = _random.nextInt(4) + 1; // 1, 2, 3 veya 4 görev
    final missionColorInfos = shuffledPalette.take(missionCount).toList();
    final decoyColorInfos = shuffledPalette.skip(missionCount).toList();
    _decoyColors = decoyColorInfos.map((c) => c.color).toSet();

    // Piramitteki tüm hücreleri oluştur (layer, o katmana özgü yerel satır/sütun).
    final cellPositions = <List<int>>[];
    for (int k = 0; k < _numLayers; k++) {
      final size = _bottomSize - 2 * k;
      for (int r = 0; r < size; r++) {
        for (int c = 0; c < size; c++) {
          cellPositions.add([k, r, c]);
        }
      }
    }
    final totalCubes = cellPositions.length;

    // Renk havuzunu oluştur: %78 görev rengi, %22 "yanlış" (dekoy) renk.
    const decoyRatio = 0.22;
    final decoyCubeCount = (totalCubes * decoyRatio).round();
    final missionCubeCount = totalCubes - decoyCubeCount;

    final colorPool = <Color>[];
    for (int i = 0; i < missionCubeCount; i++) {
      colorPool.add(missionColorInfos[i % missionColorInfos.length].color);
    }
    for (int i = 0; i < decoyCubeCount; i++) {
      colorPool.add(decoyColorInfos[i % decoyColorInfos.length].color);
    }
    colorPool.shuffle(_random);

    cellPositions.shuffle(_random);
    final cubes = <_Cube>[];
    for (int i = 0; i < cellPositions.length; i++) {
      final pos = cellPositions[i];
      cubes.add(_Cube(layer: pos[0], row: pos[1], col: pos[2], color: colorPool[i]));
    }

    final counts = <Color, int>{};
    for (final cube in cubes) {
      counts[cube.color] = (counts[cube.color] ?? 0) + 1;
    }

    _missions = missionColorInfos.map((info) {
      final total = counts[info.color] ?? 0;
      final ratio = 0.5 + _random.nextDouble() * 0.3;
      final target = (total * ratio).round().clamp(3, total == 0 ? 3 : total);
      return _Mission(color: info.color, label: info.label, target: target);
    }).toList();

    _grid = List.generate(_numLayers, (k) {
      final size = _bottomSize - 2 * k;
      return List.generate(size, (r) => List.generate(size, (c) => null));
    });
    for (final cube in cubes) {
      _grid[cube.layer][cube.row][cube.col] = cube;
    }
    _allCubes = cubes;

    _removalHistory.clear();
    _undoCount = 3;
    _shuffleCount = 3;
    _bombCount = 3;
    _bombArmed = false;
    _mistakesAllowed = (decoyCubeCount * 0.45).round().clamp(3, 15);
    _mistakesUsed = 0;
    _theta = 0;
    _status = _Status.playing;
  }

  /// Bir küp, ANCAK doğrudan üstünde oturan TEK küp kaldırılmışsa (ya da
  /// hiç yoksa) açığa çıkar. Basamaklı yapı sayesinde bu ilişki her zaman
  /// "üst katmanda aynı satır/sütundan 1 eksik" konumdaki tek küpe bakmak
  /// kadar basit.
  bool _isExposed(int layer, int row, int col) {
    if (layer == _numLayers - 1) return true;
    final aboveLayer = layer + 1;
    final aboveSize = _bottomSize - 2 * aboveLayer;
    final aboveRow = row - 1;
    final aboveCol = col - 1;
    if (aboveRow < 0 || aboveRow >= aboveSize || aboveCol < 0 || aboveCol >= aboveSize) {
      return true;
    }
    final above = _grid[aboveLayer][aboveRow][aboveCol];
    return above == null || above.removed;
  }

  _Mission? _missionFor(Color color) {
    for (final m in _missions) {
      if (m.color == color) return m;
    }
    return null;
  }

  bool _isDecoy(Color color) => _decoyColors.contains(color);

  void _vibrate(int duration) {
    if (!SettingsManager.instance.vibrationEnabled) return;
    Vibration.hasVibrator().then((has) {
      if (has == true) Vibration.vibrate(duration: duration);
    });
  }

  void _onCubeTap(_Cube cube) {
    if (_status != _Status.playing) return;
    if (cube.removed) return;

    if (_bombArmed) {
      _removeCube(cube);
      _bombCount--;
      _bombArmed = false;
      _vibrate(50);
      return;
    }

    if (!_isExposed(cube.layer, cube.row, cube.col)) return;
    _removeCube(cube);
    _vibrate(20);
  }

  void _removeCube(_Cube cube) {
    setState(() {
      cube.removed = true;
      _removalHistory.add(cube);

      if (_isDecoy(cube.color)) {
        _mistakesUsed++;
        if (_mistakesUsed > _mistakesAllowed) {
          _status = _Status.levelFailed;
          _vibrate(150);
          return;
        }
      } else {
        final mission = _missionFor(cube.color);
        if (mission != null && mission.progress < mission.target) {
          mission.progress++;
        }
      }

      if (_missions.every((m) => m.isComplete)) {
        _status = _Status.levelComplete;
        _bestLevel = _level;
        StorageManager.instance.submitScore(_bestLevel);
        _vibrate(120);
      }
    });
  }

  void _undo() {
    if (_status != _Status.playing) return;
    if (_undoCount <= 0 || _removalHistory.isEmpty) return;
    setState(() {
      final cube = _removalHistory.removeLast();
      cube.removed = false;
      if (_isDecoy(cube.color)) {
        if (_mistakesUsed > 0) _mistakesUsed--;
      } else {
        final mission = _missionFor(cube.color);
        if (mission != null && mission.progress > 0) mission.progress--;
      }
      _undoCount--;
    });
  }

  void _shuffleRemaining() {
    if (_status != _Status.playing) return;
    if (_shuffleCount <= 0) return;
    setState(() {
      final remaining = _allCubes.where((c) => !c.removed).toList();
      final colors = remaining.map((c) => c.color).toList()..shuffle(_random);
      for (int i = 0; i < remaining.length; i++) {
        remaining[i].color = colors[i];
      }
      _shuffleCount--;
      _bombArmed = false;
    });
  }

  void _armBomb() {
    if (_status != _Status.playing) return;
    if (_bombCount <= 0) return;
    setState(() => _bombArmed = !_bombArmed);
  }

  void _pause() {
    if (_status != _Status.playing) return;
    setState(() => _status = _Status.paused);
  }

  void _resume() {
    setState(() => _status = _Status.playing);
  }

  void _restartLevel() {
    setState(_generateLevel);
  }

  void _nextLevel() {
    setState(() {
      _level++;
      _generateLevel();
    });
  }

  Offset _cubeAnchor(_Cube cube, Size canvasSize) {
    // Mutlak konum: o katmanın yerel satır/sütununa, katman numarası kadar
    // payanda ekleniyor - böylece TÜM katmanlar aynı tek koordinat
    // sistemine oturuyor, aralarında yarım hücre kayma OLMUYOR.
    final absRow = (cube.layer + cube.row).toDouble();
    final absCol = (cube.layer + cube.col).toDouble();
    final center = (_bottomSize - 1) / 2.0;
    final rC = absRow - center;
    final cC = absCol - center;

    // Dikey eksen etrafında döndürme (kullanıcı sürükleyince değişir).
    final cosT = cos(_theta);
    final sinT = sin(_theta);
    final rx = cC * cosT - rC * sinT;
    final rz = cC * sinT + rC * cosT;

    final originX = canvasSize.width / 2;
    final originY = canvasSize.height * 0.42;
    final x = originX + (rx - rz) * (_tileWidth / 2);
    final y = originY + (rx + rz) * (_tileHeight / 2) - cube.layer * _cubeDepth;
    return Offset(x, y);
  }

  /// Küpleri, ekranda çizildikleri sırayla döndürür (arkadan öne, alttan
  /// üste). Hem çizim hem isabet testi bu ORTAK sıralamayı kullanır.
  /// ÖNEMLİ: piramit döndürüldüğünde hangi küpün önde göründüğü de
  /// değişir, bu yüzden sıralama sabit değil, o anki açıya göre (gerçek
  /// ekran Y konumuna göre) HER SEFERİNDE yeniden hesaplanır.
  List<_Cube> _paintOrder(Size canvasSize) {
    final visible = _allCubes.where((c) => !c.removed).toList();
    visible.sort((a, b) {
      final ay = _cubeAnchor(a, canvasSize).dy;
      final by = _cubeAnchor(b, canvasSize).dy;
      return ay.compareTo(by);
    });
    return visible;
  }

  void _handleTapAt(Offset position, Size canvasSize) {
    final order = _paintOrder(canvasSize);
    // En üstte çizilen (en önde görünen) küpten başlayarak kontrol et.
    for (final cube in order.reversed) {
      final anchor = _cubeAnchor(cube, canvasSize);
      final faces = _CubeFaces(anchor, _tileWidth, _tileHeight, _cubeDepth);
      if (faces.contains(position)) {
        _onCubeTap(cube);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0E1A),
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _TopBar(
                    level: _level,
                    mistakesRemaining: (_mistakesAllowed - _mistakesUsed).clamp(0, _mistakesAllowed),
                    onPause: _pause,
                  ),
                  const SizedBox(height: 8),
                  _MissionBar(missions: _missions),
                  const Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(
                      '↔  Piramidi döndürmek için sürükle',
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final canvasSize =
                            Size(constraints.maxWidth, constraints.maxHeight);
                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onPanStart: (details) {
                            _dragStart = details.localPosition;
                            _dragTotalMovement = 0;
                            _isDragRotating = false;
                          },
                          onPanUpdate: (details) {
                            _dragTotalMovement += details.delta.dx.abs();
                            if (_dragTotalMovement > _rotationDragThreshold) {
                              setState(() {
                                _isDragRotating = true;
                                _theta += details.delta.dx * _rotationSpeed;
                              });
                            }
                          },
                          onPanEnd: (details) {
                            if (!_isDragRotating) {
                              _handleTapAt(_dragStart, canvasSize);
                            }
                          },
                          child: CustomPaint(
                            size: canvasSize,
                            painter: _PyramidPainter(
                              cubes: _paintOrder(canvasSize),
                              anchorOf: (cube) => _cubeAnchor(cube, canvasSize),
                              tileWidth: _tileWidth,
                              tileHeight: _tileHeight,
                              cubeDepth: _cubeDepth,
                              isExposed: _isExposed,
                              bombArmed: _bombArmed,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  _PowerUpBar(
                    undoCount: _undoCount,
                    shuffleCount: _shuffleCount,
                    bombCount: _bombCount,
                    bombArmed: _bombArmed,
                    onUndo: _undo,
                    onShuffle: _shuffleRemaining,
                    onBomb: _armBomb,
                  ),
                ],
              ),
              if (_status == _Status.paused)
                PauseOverlay(
                  onResume: _resume,
                  onRestart: _restartLevel,
                  onHome: () => Navigator.of(context).pop(),
                ),
              if (_status == _Status.levelComplete)
                LevelCompleteOverlay(
                  level: _level,
                  onNextLevel: _nextLevel,
                  onHome: () => Navigator.of(context).pop(),
                ),
              if (_status == _Status.levelFailed)
                LevelFailedOverlay(
                  onRetry: _restartLevel,
                  onHome: () => Navigator.of(context).pop(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.level,
    required this.mistakesRemaining,
    required this.onPause,
  });
  final int level;
  final int mistakesRemaining;
  final VoidCallback onPause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          InkWell(
            onTap: onPause,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.35),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.pause_rounded, color: Colors.white, size: 22),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.favorite_rounded, color: Color(0xFFFF5C5C), size: 16),
                const SizedBox(width: 4),
                Text(
                  '$mistakesRemaining',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'SEVİYE $level',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionBar extends StatelessWidget {
  const _MissionBar({required this.missions});
  final List<_Mission> missions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: missions
            .map((m) => Expanded(child: _MissionCard(mission: m)))
            .toList(),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission});
  final _Mission mission;

  @override
  Widget build(BuildContext context) {
    final progressRatio =
        mission.target == 0 ? 1.0 : (mission.progress / mission.target).clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFF1B1F35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: mission.color,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  mission.label,
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progressRatio,
              minHeight: 6,
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(mission.color),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${mission.progress} / ${mission.target}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PowerUpBar extends StatelessWidget {
  const _PowerUpBar({
    required this.undoCount,
    required this.shuffleCount,
    required this.bombCount,
    required this.bombArmed,
    required this.onUndo,
    required this.onShuffle,
    required this.onBomb,
  });

  final int undoCount;
  final int shuffleCount;
  final int bombCount;
  final bool bombArmed;
  final VoidCallback onUndo;
  final VoidCallback onShuffle;
  final VoidCallback onBomb;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _PowerUpButton(
            icon: Icons.undo_rounded,
            label: 'Geri Al',
            count: undoCount,
            onTap: onUndo,
          ),
          _PowerUpButton(
            icon: Icons.shuffle_rounded,
            label: 'Karıştır',
            count: shuffleCount,
            onTap: onShuffle,
          ),
          _PowerUpButton(
            icon: Icons.whatshot_rounded,
            label: 'Bomba',
            count: bombCount,
            onTap: onBomb,
            highlighted: bombArmed,
          ),
        ],
      ),
    );
  }
}

class _PowerUpButton extends StatelessWidget {
  const _PowerUpButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final disabled = count <= 0;
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 92,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF1B1F35),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlighted
                ? const Color(0xFF00F5FF)
                : Colors.white.withOpacity(0.08),
            width: highlighted ? 2 : 1,
          ),
        ),
        child: Opacity(
          opacity: disabled ? 0.4 : 1,
          child: Column(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, color: Colors.white, size: 26),
                  Positioned(
                    right: -8,
                    top: -6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00F5FF),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          color: Colors.black,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PyramidPainter extends CustomPainter {
  _PyramidPainter({
    required this.cubes,
    required this.anchorOf,
    required this.tileWidth,
    required this.tileHeight,
    required this.cubeDepth,
    required this.isExposed,
    required this.bombArmed,
  });

  /// Çizim sırasına göre (arkadan öne) sıralanmış görünür küpler.
  final List<_Cube> cubes;
  final Offset Function(_Cube cube) anchorOf;
  final double tileWidth;
  final double tileHeight;
  final double cubeDepth;
  final bool Function(int layer, int row, int col) isExposed;
  final bool bombArmed;

  @override
  void paint(Canvas canvas, Size size) {
    for (final cube in cubes) {
      final exposed = isExposed(cube.layer, cube.row, cube.col);
      _drawCube(canvas, cube, exposed);
    }
  }

  void _drawCube(Canvas canvas, _Cube cube, bool exposed) {
    final anchor = anchorOf(cube);
    final faces = _CubeFaces(anchor, tileWidth, tileHeight, cubeDepth);

    // Küpler HER ZAMAN tam opak (dolu renk) çizilir - saydamlık yok.
    final baseColor = cube.color;
    final topColor = _shade(baseColor, 1.25);
    final leftColor = _shade(baseColor, 0.72);
    final rightColor = _shade(baseColor, 0.9);

    canvas.drawPath(faces.leftFace, Paint()..color = leftColor);
    canvas.drawPath(faces.rightFace, Paint()..color = rightColor);
    canvas.drawPath(faces.topFace, Paint()..color = topColor);

    final strokePaint = Paint()
      ..color = Colors.black.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawPath(faces.topFace, strokePaint);
    canvas.drawPath(faces.leftFace, strokePaint);
    canvas.drawPath(faces.rightFace, strokePaint);

    // Açıkta olan (dokunulabilir) küplere ince parlak bir çerçeve.
    if (exposed) {
      canvas.drawPath(
        faces.topFace,
        Paint()
          ..color = Colors.white.withOpacity(0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }

    if (bombArmed && exposed) {
      canvas.drawPath(
        faces.topFace,
        Paint()
          ..color = Colors.redAccent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }
  }

  Color _shade(Color color, double factor) {
    final hsl = HSLColor.fromColor(color);
    final adjusted = hsl.withLightness((hsl.lightness * factor).clamp(0.0, 1.0));
    return adjusted.toColor();
  }

  @override
  bool shouldRepaint(covariant _PyramidPainter oldDelegate) => true;
}
