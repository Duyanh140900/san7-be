import 'package:material_ui/material_ui.dart';

/// Asset ảnh dùng xuyên suốt giao diện Floodlight Night.
///
/// Luôn ưu tiên ảnh thật khi API chưa cung cấp ảnh tải lên, thay vì để một
/// khoảng nền trống. [forId] chọn ảnh ổn định, nên cùng một bản ghi luôn có
/// cùng ảnh minh hoạ ở mọi màn hình.
abstract final class PitchImages {
  static const appLogo = 'assets/images/app_logo.jpg';
  static const welcomeStadium = 'assets/images/welcome_stadium.jpg';
  static const pitchNight1 = 'assets/images/pitch_night_1.jpg';
  static const pitchNight2 = 'assets/images/pitch_night_2.jpg';
  static const pitchNight3 = 'assets/images/pitch_night_3.jpg';
  static const pitchMatch1 = 'assets/images/pitch_match_1.jpg';
  static const playerCelebrate = 'assets/images/player_celebrate.webp';
  static const trophyCupWard = 'assets/images/trophy_cup_ward.webp';
  static const avatarDefault = 'assets/images/avatar_default.webp';

  static const icon3dBall = 'assets/images/icon3d_ball.webp';
  static const icon3dBoots = 'assets/images/icon3d_boots.webp';
  static const icon3dClock = 'assets/images/icon3d_clock.webp';
  static const icon3dCup = 'assets/images/icon3d_cup.webp';
  static const icon3dJersey = 'assets/images/icon3d_jersey.webp';
  static const icon3dRedCard = 'assets/images/icon3d_red_card.webp';
  static const icon3dWhistle = 'assets/images/icon3d_whistle.webp';
  static const icon3dYellowCard = 'assets/images/icon3d_yellow_card.webp';
  static const stateEmpty = 'assets/images/state_empty.jpg';

  static const _pitches = [pitchNight1, pitchNight2, pitchNight3, pitchMatch1];

  /// Chọn ảnh sân theo hash ổn định của [id].
  static String forId(String id) {
    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = ((hash * 31) + unit) & 0x7fffffff;
    }
    return _pitches[hash % _pitches.length];
  }

  /// Ảnh sân có lớp phủ tối phía đáy để nội dung trắng/lime luôn dễ đọc.
  static Widget withBottomGradient({
    required String id,
    String? imageUrl,
    BoxFit fit = BoxFit.cover,
    Alignment alignment = Alignment.center,
  }) => Stack(
    fit: StackFit.expand,
    children: [
      if (imageUrl != null && imageUrl.isNotEmpty)
        Image.network(
          imageUrl,
          fit: fit,
          alignment: alignment,
          errorBuilder: (_, _, _) =>
              Image.asset(forId(id), fit: fit, alignment: alignment),
        )
      else
        Image.asset(forId(id), fit: fit, alignment: alignment),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x0006110B), Color(0xD906110B)],
            stops: [0.32, 1],
          ),
        ),
      ),
    ],
  );
}
