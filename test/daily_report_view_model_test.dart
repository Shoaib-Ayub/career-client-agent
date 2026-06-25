import 'dart:io';

import 'package:career_client_agent/features/daily_report/view_model/daily_report_view_model.dart';
import 'package:career_client_agent/features/opportunities/model/opportunity_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp();
    Hive.init(hiveDirectory.path);
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('daily report applies freshness filters', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initial = await container.read(dailyReportViewModelProvider.future);
    expect(initial.selectedFilter, OpportunityFilter.today);

    container
        .read(dailyReportViewModelProvider.notifier)
        .selectFilter(OpportunityFilter.last7Days);
    final last7Days = container.read(dailyReportViewModelProvider).requireValue;

    expect(last7Days.total, greaterThanOrEqualTo(initial.total));
  });
}
