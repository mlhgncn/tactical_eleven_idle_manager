import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tactical_eleven_idle_manager/models/club_info.dart';
import 'package:tactical_eleven_idle_manager/models/inbox_message.dart';
import 'package:tactical_eleven_idle_manager/models/player_fm.dart';
import 'package:tactical_eleven_idle_manager/models/profile.dart';
import 'package:tactical_eleven_idle_manager/models/transfer_market_item.dart';
import 'package:tactical_eleven_idle_manager/providers/game_provider.dart';
import 'package:tactical_eleven_idle_manager/repositories/repository_interface.dart';
import 'package:tactical_eleven_idle_manager/screens/auth_screen.dart';
import 'package:tactical_eleven_idle_manager/screens/email_verification_screen.dart';
import 'package:tactical_eleven_idle_manager/screens/root_shell.dart';
import 'package:tactical_eleven_idle_manager/screens/setup_club_screen.dart';
import 'package:tactical_eleven_idle_manager/services/auth_repository.dart';

class _FakeAuthRepository implements AuthRepository {
  @override
  String? get currentUserId => 'test-user-1';

  @override
  Future<dynamic> signIn(String email, String password) async {
    return _FakeAuthResponse(
      user: _FakeUser(id: currentUserId!),
      session: _FakeSession(user: _FakeUser(id: currentUserId!)),
    );
  }

  @override
  Future<dynamic> signUp(String email, String password) async {
    return _FakeAuthResponse(
      user: _FakeUser(id: currentUserId!),
      session: _FakeSession(user: _FakeUser(id: currentUserId!)),
    );
  }

  @override
  Future<void> signOut() async {
    return;
  }
}

class _FakeAuthResponse {
  final _FakeUser user;
  final _FakeSession? session;

  _FakeAuthResponse({required this.user, required this.session});
}

class _FakeUser {
  final String id;
  final DateTime? emailConfirmedAt = DateTime.now();

  _FakeUser({required this.id});
}

class _FakeSession {
  final _FakeUser user;
  final DateTime? emailConfirmedAt = DateTime.now();

  _FakeSession({required this.user});
}

class _FakeGameRepository implements GameRepository {
  String? _currentUserId = 'test-user-1';
  ClubInfo? _activeClub;
  final List<ClubInfo> _availableClubs = [
    const ClubInfo(
      id: 'club-1',
      name: 'Test United',
      budget: 10000,
      stadiumCapacity: 5000,
      ticketPrice: 5,
      trainingFacilityLevel: 1,
      sponsorLevel: 1,
    ),
    const ClubInfo(
      id: 'club-2',
      name: 'Demo City',
      budget: 9500,
      stadiumCapacity: 4500,
      ticketPrice: 5,
      trainingFacilityLevel: 1,
      sponsorLevel: 1,
    ),
  ];

  @override
  String? get currentUserId => _currentUserId;

  @override
  Future<ClubInfo?> loadActiveClub() async => _activeClub;

  @override
  Future<Profile?> loadProfile() async {
    return Profile(
      id: currentUserId ?? 'unknown',
      fullName: 'Test Manager',
      avatarUrl: null,
      email: 'test@example.com',
      language: 'tr',
      fcmToken: null,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<ClubInfo>> loadAvailableClubs() async => _availableClubs;

  @override
  Future<ClubInfo?> createClub(String name) async {
    final club = ClubInfo(
      id: 'club-created',
      name: name,
      budget: 10000,
      stadiumCapacity: 5000,
      ticketPrice: 5,
      trainingFacilityLevel: 1,
      sponsorLevel: 1,
      lastMaintenanceDate: DateTime.now(),
    );
    _activeClub = club;
    return club;
  }

  @override
  Future<ClubInfo?> claimClub(String clubId) async {
    final club = _availableClubs.firstWhere((club) => club.id == clubId, orElse: () => _availableClubs.first);
    _activeClub = club;
    return club;
  }

  @override
  Future<List<PlayerFM>> loadSquadPlayers(String clubId) async {
    return List<PlayerFM>.generate(
      11,
      (index) => PlayerFM(
        id: 'player-$index',
        clubId: clubId,
        name: 'Test Player ${index + 1}',
        position: 'Position ${index + 1}',
        age: 19 + (index % 5),
        currentAbility: 50 + index,
        potentialAbility: 60 + index,
        morale: 80,
        fitness: 90,
        finishing: 70,
        passing: 65,
        tackling: 60,
        composure: 62,
        determination: 68,
        consistency: 70,
        injuryProneness: 10,
      ),
    );
  }

  @override
  Future<List<InboxMessage>> loadInboxMessages() async => <InboxMessage>[];

  @override
  Future<List<TransferMarketItem>> loadTransferMarket() async => <TransferMarketItem>[];

  @override
  Future<TransferMarketItem?> placeBid(String marketId, int bidAmount) async => null;

  @override
  Future<ClubInfo?> acceptTransferOffer({required String clubId, required int newBudget, required String playerId}) async => null;

  @override
  Future<bool> markMessageAsRead(String messageId) async => true;

  @override
  Future<ClubInfo?> upgradeClub({required String clubId, int? stadiumCapacity, int? trainingFacilityLevel, int? ticketPrice, required int budget}) async {
    if (_activeClub == null) return null;
    final updatedClub = _activeClub!.copyWith(
      budget: budget,
      stadiumCapacity: stadiumCapacity ?? _activeClub!.stadiumCapacity,
      trainingFacilityLevel: trainingFacilityLevel ?? _activeClub!.trainingFacilityLevel,
      ticketPrice: ticketPrice ?? _activeClub!.ticketPrice,
    );
    _activeClub = updatedClub;
    return updatedClub;
  }

  @override
  Future<void> updateFcmToken(String token) async {}
}

void main() {
  testWidgets('Full game flow from zero account to match play', (WidgetTester tester) async {
    print('[TEST 1] Starting test');
    TestWidgetsFlutterBinding.ensureInitialized();
    print('[TEST 2] Binding initialized');
    
    // Initialize Supabase with dummy values for test
    print('[TEST] Initializing Supabase for test');
    try {
      await Supabase.initialize(
        url: 'https://test.supabase.co',
        anonKey: 'test-anon-key',
      );
      print('[TEST] Supabase initialized');
    } catch (e) {
      print('[TEST] Supabase already initialized or error: $e');
    }
    
    // Skip EasyLocalization.ensureInitialized() since it blocks in tests
    // We provide a fixed locale in the widget tree instead
    print('[TEST 3] Skipping EasyLocalization init');

    print('[TEST 4] Creating test data');
    final fakeAuth = _FakeAuthRepository();
    final fakeRepo = _FakeGameRepository();
    
    bool notificationSent = false;
    Future<void> testNotificationSender(String title, String body) async {
      notificationSent = true;
      expect(title, contains('Maç Sonucu'));
      expect(body, contains('Zero Account FC'));
    }

    final gameProvider = GameProvider(
      repository: fakeRepo,
      notificationSender: testNotificationSender,
      enableRealtime: false,
    );

    print('[TEST 5] About to pump widget');
    await tester.pumpWidget(
      EasyLocalization(
        startLocale: const Locale('tr'),
        supportedLocales: const [Locale('tr')],
        path: 'assets/translations',
        fallbackLocale: const Locale('tr'),
        child: ChangeNotifierProvider<GameProvider>.value(
          value: gameProvider,
          child: MaterialApp(
            initialRoute: '/auth',
            routes: {
              '/auth': (_) => AuthScreen(authRepository: fakeAuth),
              '/email-verification': (_) => const EmailVerificationScreen(),
              '/setup-club': (_) => SetupClubScreen(),
              '/root': (_) => RootShell(),
            },
          ),
        ),
      ),
    );

    print('[TEST 6] Widget pumped, about to settle');
    await tester.pumpAndSettle(const Duration(seconds: 5));
    print('[TEST 7] Settled, finding login button');
    expect(find.text('Giriş Yap'), findsWidgets);

    await tester.tap(find.text('Henüz hesabın yok mu? Kayıt ol'));
    await tester.pumpAndSettle();
    expect(find.text('Kayıt Ol'), findsWidgets);

    print('[TEST] Finding TextFormFields...');
    final textFields = find.byType(TextFormField);
    expect(textFields, findsWidgets);
    print('[TEST] Found ${textFields.evaluate().length} TextFormFields');
    
    // Find and fill the email field (first TextFormField)
    print('[TEST] Entering email...');
    await tester.enterText(textFields.at(0), 'test@example.com');
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    
    // Find and fill the password field (second TextFormField)
    print('[TEST] Entering password...');
    await tester.enterText(textFields.at(1), 'password123');
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    print('[TEST] Tapping signup button...');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Kayıt Ol'));
    print('[TEST] Tapped signup button, settling...');
    await tester.pumpAndSettle();
    print('[TEST] Settled after signup');
    
    // Debug: print all text widgets to see what's on screen
    final allText = find.byType(Text);
    print('[TEST] Total Text widgets: ${allText.evaluate().length}');
    for (final widget in allText.evaluate()) {
      if (widget.widget is Text) {
        print('[TEST] Found text: ${(widget.widget as Text).data}');
      }
    }
    
    expect(find.text('Kulüp Kurulumu'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Zero Account FC');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Kulüp Oluştur'));
    print('[TEST] Tapped create club button, settling...');
    await tester.pumpAndSettle();
    print('[TEST] Settled after club creation');
    
    // Debug: print all text widgets to see what's on screen
    final allText2 = find.byType(Text);
    print('[TEST] After club creation, found ${allText2.evaluate().length} Text widgets');
    for (final widget in allText2.evaluate().take(20)) {
      if (widget.widget is Text) {
        print('[TEST] Found text: ${(widget.widget as Text).data}');
      }
    }

    expect(find.text('Kulüp Finansları'), findsOneWidget);
    expect(gameProvider.activeClub, isNotNull);
    expect(gameProvider.activeClub!.name, 'Zero Account FC');

    await tester.tap(find.text('Kadro'));
    await tester.pumpAndSettle();
    expect(find.text('Test Player 1'), findsOneWidget);

    await tester.tap(find.text('Taktik'));
    await tester.pumpAndSettle();
    expect(find.text('Taktik Paneli'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Taktikleri Kaydet'));
    await tester.pumpAndSettle();

    final initialBudget = gameProvider.activeClub!.budget;
    await gameProvider.playNextFixture();
    await tester.pumpAndSettle();

    expect(gameProvider.results, isNotEmpty);
    expect(gameProvider.inboxMessages.first.title, 'Maç Sonucu');
    expect(gameProvider.activeClub!.budget, greaterThan(initialBudget));
    expect(notificationSent, isTrue);
  });
}
