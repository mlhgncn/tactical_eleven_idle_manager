import 'package:flutter_test/flutter_test.dart';
import 'package:tactical_eleven_idle_manager/models/player_fm.dart';

void main() {
  test('injured players are flagged and labeled', () {
    final player = PlayerFM(
      id: 'player-1',
      clubId: 'club-1',
      name: 'Test Player',
      position: 'ST',
      age: 27,
      currentAbility: 80,
      potentialAbility: 85,
      injuryDurationWeeks: 3,
      injuryType: 'diz sakatlığı',
      isSuspended: true,
    );

    expect(player.hasActiveInjury, isTrue);
    expect(player.injuryDisplayLabel, contains('diz sakatlığı'));
  });
}
