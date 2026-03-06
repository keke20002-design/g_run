import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Abstract base class for all player wheel skins.
/// This allows for modular visual effects that cleanly react to game state.
abstract class WheelSkin extends PositionComponent {
  Color themeColor;
  double currentSpeed = 0;

  WheelSkin({
    required this.themeColor,
    super.size,
    super.anchor = Anchor.center,
  });

  /// Updates the movement speed for speed-dependent animations.
  void setSpeed(double speed) {
    currentSpeed = speed;
  }

  /// Triggered when the player flips gravity to provide visual feedback.
  void triggerGravityFlip();

  /// Hooks for when the skin is equipped or removed.
  void onEquip() {}
  void onUnequip() {}
}
