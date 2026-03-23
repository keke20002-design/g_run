import 'dart:math';
import 'package:flame/components.dart';
import 'gravity_flip_game.dart';
import 'item.dart';

class ItemSpawner extends Component with HasGameReference<GravityFlipGame> {
  double _spawnTimer       = 8.0;  // first item at ~8 s
  int    _lastComboTrigger = 0;
  final  _rng              = Random();

  @override
  void update(double dt) {
    if (game.state != GameState.playing) return;

    _spawnTimer -= dt;

    // Timer-based: every 10 seconds
    if (_spawnTimer <= 0) {
      _spawnTimer = 10.0;
      _trySpawn();
    }

    // Combo-based: every 5 combo steps (5, 10, 15 …)
    final combo = game.scoreSystem.combo;
    if (combo >= 5 && combo ~/ 5 > _lastComboTrigger) {
      _lastComboTrigger = combo ~/ 5;
      _trySpawn();
    }
  }

  void _trySpawn() {
    // Max 1 item on screen at a time
    if (game.children.whereType<ItemComponent>().isNotEmpty) return;

    // Build available pool
    final available = ItemType.values.where((t) {
      if (t == ItemType.secondChance) {
        // Skip if already obtained this run
        return !game.secondChanceObtained;
      }
      return true;
    }).toList();

    if (available.isEmpty) return;

    final type   = available[_rng.nextInt(available.length)];
    final spawnX = game.size.x + ItemComponent.itemSize;

    // Spawn at floor or ceiling — where the player actually is.
    // Player center Y on floor  = screenH - 34 - 8 + 17 ≈ screenH - 25
    // Player center Y on ceiling = 8 + 17 = 25
    final atFloor = _rng.nextBool();
    final spawnY  = atFloor ? game.size.y - 25.0 : 25.0;

    game.add(ItemComponent(pos: Vector2(spawnX, spawnY), type: type));
  }
}
