import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:card_cricket/shared/models/card_model.dart';
import 'package:card_cricket/shared/models/player.dart';
import 'package:card_cricket/shared/widgets/cricket_card.dart';

void main() {
  testWidgets('CricketCard renders the player name and key stats', (WidgetTester tester) async {
    final card = CardModel(
      id: 'card-1',
      rarity: 'RARE',
      rating: 82,
      imageUrl: null,
      player: const Player(
        id: 'player-1',
        name: 'Ravichandran Ashwin',
        displayName: 'Ravichandran Ashwin',
        country: 'India',
        role: 'BOWLER',
        team: 'India',
      ),
      statistics: PlayerStatistics(const {
        'matchesPlayed': 96,
        'runs': 653,
        'wickets': 133,
        'economyRate': 4.85,
        'bestBowling': '4/25',
      }),
      selectableStatistics: const ['matchesPlayed', 'runs', 'wickets', 'economyRate'],
    );

    await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: Center(child: CricketCard(card: card)))),
    );

    expect(find.text('RAVICHANDRAN ASHWIN'), findsOneWidget);
    expect(find.text('133'), findsOneWidget); // wickets
    expect(find.text('4/25'), findsOneWidget); // best bowling (display-only)
    expect(find.text('INDIA'), findsOneWidget);
  });
}
