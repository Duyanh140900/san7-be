import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../api/san7_api.dart';
import '../../../core/api/api_call.dart';
import '../../../core/api/api_client.dart';

/// Quỹ đội: tổng quan, khoản thu/chi/phạt, luật phạt.
class FundsRepository {
  FundsRepository(this._api, this._dio);
  final San7Api _api;
  final Dio _dio;

  /// Tải ảnh biên lai (cần Bearer, Dio đã gắn sẵn).
  Future<Uint8List> receiptBytes(String url) => apiCall(() async {
    final res = await _dio.get<List<int>>(url, options: Options(responseType: ResponseType.bytes));
    return Uint8List.fromList(res.data ?? const []);
  });

  Future<FundSummaryDto> summary(String teamId) =>
      apiCall(() => _api.funds.fundsSummary(teamId: teamId));

  Future<FundTxPageDto> transactions(String teamId, {String? cursor}) =>
      apiCall(() => _api.funds.fundsList(teamId: teamId, cursor: cursor, limit: 20));

  Future<List<FundTxDto>> create(String teamId, CreateFundTxDto body) =>
      apiCall(() => _api.funds.fundsCreate(teamId: teamId, body: body));

  Future<FundTxDto> markFinePaid(String teamId, String txId) =>
      apiCall(() => _api.funds.fundsMarkFinePaid(teamId: teamId, txId: txId));

  Future<void> remove(String teamId, String txId) =>
      apiCall(() => _api.funds.fundsRemove(teamId: teamId, txId: txId));

  Future<List<FineRuleDto>> fineRules(String teamId) =>
      apiCall(() => _api.funds.fundsFineRules(teamId: teamId));

  Future<FineRuleDto> createFineRule(String teamId, String name, int amount) => apiCall(
    () => _api.funds.fundsCreateFineRule(
      teamId: teamId,
      body: CreateFineRuleDto(name: name, amount: amount),
    ),
  );

  Future<void> removeFineRule(String teamId, String ruleId) =>
      apiCall(() => _api.funds.fundsRemoveFineRule(teamId: teamId, ruleId: ruleId));
  Future<Map<String, dynamic>> claimTransfer(
    String teamId, {
    required int amount,
    required String transferCode,
    String? note,
  }) => apiCall(() async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/teams/$teamId/funds/transfer-claims',
      data: {
        'amount': amount,
        'transferCode': transferCode,
        'note': ?note,
      },
    );
    return res.data ?? {};
  });

  Future<void> updateTreasurerAccount(
    String teamId, {
    required String bankBin,
    required String accountNo,
    required String accountName,
  }) => apiCall(() async {
    await _dio.patch(
      '/v1/teams/$teamId/treasurer-account',
      data: {
        'treasurerBankBin': bankBin,
        'treasurerAccountNo': accountNo,
        'treasurerAccountName': accountName,
      },
    );
  });
}

final fundsRepositoryProvider = Provider<FundsRepository>(
  (ref) => FundsRepository(ref.watch(apiProvider), ref.watch(dioProvider)),
);
